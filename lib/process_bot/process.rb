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

  def stop
    @stopped = true
  end

  def handler_class
    @handler_class ||= begin
      require_relative "process/handlers/#{options.fetch(:handler)}"
      ProcessBot::Process::Handlers.const_get(StringCases.snake_to_camel(options.fetch(:handler)))
    end
  end

  def execute!
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

  def run
    handler_instance = handler_class.new(options)
    runner = ProcessBot::Process::Runner.new(command: handler_instance.command, logger: logger, options: options)
    runner.run
  end

  def update_process_title
    @current_process_title = "ProcessBot #{options.fetch(:handler)} PID #{current_pid} port #{port}"
    Process.setproctitle(current_process_title)
  end
end
