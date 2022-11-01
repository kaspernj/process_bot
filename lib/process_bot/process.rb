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
    @stopped = true

    raise "Sidekiq not running with a PID" unless current_pid
    Process.kill("TSTP", current_pid)
    wait_for_no_jobs_and_stop_sidekiq
  end

  def stop
    @stopped = true

    raise "Sidekiq not running with a PID" unless current_pid
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

  def wait_for_no_jobs # rubocop:disable Metrics/AbcSize
    loop do
      found_process = false

      Knj::Unix_proc.list("grep" => current_pid) do |process|
        process_command = process.data.fetch("cmd")
        process_pid = process.data.fetch("pid").to_i
        next unless process_pid == current_pid

        found_process = true
        match = process_command.match(/\Asidekiq (\d+).(\d+).(\d+) #{Regexp.escape(options.fetch(:application))} \[(\d+) of (\d+) (.+?)\]\Z/)
        raise "Couldnt match Sidekiq command: #{process_command}" unless match

        running_jobs = match[4].to_i

        puts "running_jobs: #{running_jobs}"

        return if running_jobs.zero? # rubocop:disable Lint/NonLocalExitFromIterator
      end

      raise "Couldn't find running process with PID #{current_pid}" unless found_process

      sleep 1
    end
  end

  def wait_for_no_jobs_and_stop_sidekiq
    puts "Wait for no jobs and Stop sidekiq"

    wait_for_no_jobs
    stop
  end
end
