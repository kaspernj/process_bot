require "forwardable"
require "json"
require "string-cases"

class ProcessBot::Process
  extend Forwardable

  def_delegator :handler_instance, :graceful
  def_delegator :handler_instance, :graceful_no_wait
  def_delegator :handler_instance, :stop

  autoload :Handlers, "#{__dir__}/process/handlers"
  autoload :Runner, "#{__dir__}/process/runner"

  attr_reader :current_pid, :current_process_title, :options, :port, :stopped

  def initialize(options)
    @options = options
    @stopped = false

    options.events.connect(:on_process_started, &method(:on_process_started)) # rubocop:disable Performance/MethodObjectAsBlock
    options.events.connect(:on_socket_opened, &method(:on_socket_opened)) # rubocop:disable Performance/MethodObjectAsBlock

    logger.logs("ProcessBot 1 - Options: #{options.options}")
  end

  def execute!
    command = options.fetch(:command)

    if command == "start"
      logger.logs "Starting process"
      start
    elsif command == "graceful" || command == "graceful_no_wait" || command == "stop"
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

    loop do
      run

      if stopped
        break
      else
        logger.logs "Process stopped - starting again after 1 sec"
        sleep 1
      end
    end
  end

  def stop(**args)
    logger.logs "Stop process #{args}"
    @stopped = true
    handler_instance.stop
  end

  def run
    runner.run
  end

  def send_control_command(command, **command_options)
    logger.logs "Sending #{command} command"
    response = client.send_command(command: command, options: options.options.merge(command_options))
    raise "No response from ProcessBot while sending #{command}" if response == :nil
  rescue Errno::ECONNREFUSED => e
    raise e unless options[:ignore_no_process_bot]
  end

  def runner
    @runner ||= ProcessBot::Process::Runner.new(
      command: handler_instance.start_command,
      handler_name: handler_name,
      handler_instance: handler_instance,
      logger: logger,
      options: options
    )
  end

  def update_process_title
    process_args = {application: options[:application], handler: handler_name, id: options[:id], pid: current_pid, port: port}
    @current_process_title = "ProcessBot #{JSON.generate(process_args)}"
    Process.setproctitle(current_process_title)
  end
end
