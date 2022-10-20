require "json"

class ProcessBot::Process
  autoload :Handlers, "#{__dir__}/process/handlers"
  autoload :Runner, "#{__dir__}/process/runner"

  attr_reader :current_pid, :current_process_title, :options, :port, :stopped

  def initialize(options)
    @options = options
    @stopped = false

    options.events.connect(:on_process_started, &method(:on_process_started)) # rubocop:disable Performance/MethodObjectAsBlock
    options.events.connect(:on_socket_opened, &method(:on_socket_opened)) # rubocop:disable Performance/MethodObjectAsBlock
  end

  def execute!
    command = options.fetch(:command)

    if command == "start"
      start
    elsif command == "graceful" || command == "stop"
      client.send_command(command: command)
    else
      raise "Unknown command: #{command}"
    end
  end

  def client
    @client ||= ProcessBot::ClientSocket.new(options: options)
  end

  def graceful
    @stopped = true
  end

  def handler_class
    @handler_class ||= begin
      require_relative "process/handlers/#{options.fetch(:handler)}"
      ProcessBot::Process::Handlers.const_get(StringCases.snake_to_camel(options.fetch(:handler)))
    end
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
        puts "Process stopped - starting again after 1 sec"
        sleep 1
      end
    end
  end

  def graceful
    raise "Sidekiq not running with a PID" unless current_pid

    @stopped = true
    Process.kill("TSTP", current_pid)
  end

  def stop
    raise "Sidekiq not running with a PID" unless current_pid

    @stopped = true
    Process.kill("TERM", current_pid)
  end

  def run
    handler_instance = handler_class.new(options)
    runner = ProcessBot::Process::Runner.new(command: handler_instance.start_command, logger: logger, options: options)
    runner.run
  end

  def update_process_title
    process_args = {application: options[:application], handler: options.fetch(:handler), id: options[:id], pid: current_pid, port: port}
    @current_process_title = "ProcessBot #{JSON.generate(process_args)}"
    Process.setproctitle(current_process_title)
  end
end
