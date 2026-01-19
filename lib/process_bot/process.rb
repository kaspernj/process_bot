require "forwardable"
require "json"
require "monitor"
require "string-cases"

class ProcessBot::Process
  extend Forwardable

  def_delegator :handler_instance, :graceful
  def_delegator :handler_instance, :graceful_no_wait
  def_delegator :handler_instance, :stop

  autoload :Handlers, "#{__dir__}/process/handlers"
  autoload :Runner, "#{__dir__}/process/runner"
  autoload :RunnerInstance, "#{__dir__}/process/runner_instance"

  attr_reader :control_command_monitor, :current_pid, :current_process_title, :options, :port, :stopped

  def initialize(options)
    @options = options
    @stopped = false
    @accept_control_commands = true
    @control_command_monitor = Monitor.new
    @control_commands_in_flight = 0
    @runner_events = Queue.new
    @runner_instances = []
    @runner_monitor = Monitor.new

    options.events.connect(:on_process_started, &method(:on_process_started)) # rubocop:disable Performance/MethodObjectAsBlock
    options.events.connect(:on_socket_opened, &method(:on_socket_opened)) # rubocop:disable Performance/MethodObjectAsBlock

    logger.logs("ProcessBot 1 - Options: #{options.options}")
  end

  def execute!
    command = options.fetch(:command)

    if command == "start"
      logger.logs "Starting process"
      start
    elsif command == "graceful" || command == "graceful_no_wait" || command == "restart" || command == "stop"
      send_control_command(command)
    else
      raise "Unknown command: #{command}"
    end
  end

  def client
    @client ||= ProcessBot::ClientSocket.new(options: options)
  end

  def handler_class
    @handler_class ||= begin
      require_relative "process/handlers/#{handler_name}"
      ProcessBot::Process::Handlers.const_get(StringCases.snake_to_camel(handler_name))
    end
  end

  def handler_instance
    @handler_instance ||= handler_class.new(self)
  end

  def handler_name
    @handler_name ||= options.fetch(:handler)
  end

  def logger
    @logger ||= ProcessBot::Logger.new(options: options)
  end

  def on_process_started(_event_name, pid:)
    @current_pid = pid
    update_process_title
  end

  def on_socket_opened(_event_name, port:)
    @port = port
    update_process_title
  end

  def set_stopped
    @stopped = true
  end

  def start_control_socket
    @control_socket = ProcessBot::ControlSocket.new(options: options, process: self)
    @control_socket.start
  end

  def start
    start_control_socket
    start_runner_instance

    loop do
      runner_event = runner_events.pop
      handle_runner_event(runner_event)

      next unless stopped && runner_instances.empty?

      stop_accepting_control_commands
      wait_for_control_commands
      break
    end
  end

  def restart(**_args)
    logger.logs "Restart process"

    if handler_name == "sidekiq"
      if restart_overlap?
        handler_instance.graceful_no_wait(stop_process_bot: false)
        start_runner_instance
      else
        handler_instance.graceful(stop_process_bot: false)
      end
    else
      handler_instance.stop
    end
  end

  def stop(**args)
    logger.logs "Stop process #{args}"
    @stopped = true
    handler_instance.stop
  end

  def run
    start_runner_instance
  end

  def send_control_command(command, **command_options)
    logger.logs "Sending #{command} command"
    response = client.send_command(command: command, options: options.options.merge(command_options))
    raise "No response from ProcessBot while sending #{command}" if response == :nil
  rescue Errno::ECONNREFUSED => e
    raise e unless options[:ignore_no_process_bot]
  end

  def runner
    current_runner_instance&.runner || @runner ||= build_runner
  end

  def update_process_title
    process_args = {application: options[:application], handler: handler_name, id: options[:id], pid: current_pid, port: port}
    @current_process_title = "ProcessBot #{JSON.generate(process_args)}"
    Process.setproctitle(current_process_title)
  end

  def with_control_command
    control_command_monitor.synchronize do
      @control_commands_in_flight += 1
    end

    yield
  ensure
    control_command_monitor.synchronize do
      @control_commands_in_flight -= 1
    end
  end

  def accept_control_commands?
    @accept_control_commands
  end

  def stop_accepting_control_commands
    @accept_control_commands = false
    @control_socket&.stop
  end

  def wait_for_control_commands
    sleep 0.1 while control_commands_in_flight.positive?
  end

  def control_commands_in_flight
    control_command_monitor.synchronize do
      @control_commands_in_flight
    end
  end

  def build_runner
    ProcessBot::Process::Runner.new(
      command: handler_instance.start_command,
      handler_name: handler_name,
      handler_instance: handler_instance,
      logger: logger,
      options: options
    )
  end

  def start_runner_instance
    runner_instance = ProcessBot::Process::RunnerInstance.new(
      runner: build_runner,
      event_queue: runner_events,
      logger: logger
    )

    track_runner_instance(runner_instance)
    @current_runner_instance = runner_instance
    @runner = runner_instance.runner
    runner_instance.start
  end

  def handle_runner_event(runner_event)
    runner_instance = runner_event.fetch(:runner_instance)
    remove_runner_instance(runner_instance)
    log_runner_event_error(runner_event)
    clear_current_runner(runner_instance)
    restart_runner_if_needed(runner_instance)
  end

  def runner_instances
    runner_monitor.synchronize do
      @runner_instances.dup
    end
  end

  def track_runner_instance(runner_instance)
    runner_monitor.synchronize do
      @runner_instances << runner_instance
    end
  end

  def remove_runner_instance(runner_instance)
    runner_monitor.synchronize do
      @runner_instances.delete(runner_instance)
    end
  end

  def restart_overlap?
    value = options[:sidekiq_restart_overlap]
    return false if value.nil?
    return value if value == true || value == false

    normalized = value.to_s.strip.downcase
    return false if normalized == "false" || normalized == "0" || normalized == ""

    true
  end

  def log_runner_event_error(runner_event)
    return unless runner_event.fetch(:type) == :error

    logger.error "Process runner crashed: #{runner_event.fetch(:error)}"
  end

  def clear_current_runner(runner_instance)
    return unless runner_instance == current_runner_instance

    @current_runner_instance = nil
    @runner = nil
  end

  def restart_runner_if_needed(runner_instance)
    return if stopped
    return unless runner_instance == current_runner_instance || current_runner_instance.nil?

    logger.logs "Process stopped - starting again after 1 sec"
    sleep 1
    start_runner_instance
  end

private

  attr_reader :current_runner_instance, :runner_events, :runner_monitor
end
