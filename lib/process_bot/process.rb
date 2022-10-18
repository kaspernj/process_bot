class ProcessBot::Process
  module Handlers
  end

  autoload :Runner, "#{__dir__}/process/runner"

  attr_reader :options, :stopped

  def initialize(options)
    @options = options
    @stopped = false
  end

  def logger
    @logger ||= ProcessBot::Logger.new(options: options)
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
end
