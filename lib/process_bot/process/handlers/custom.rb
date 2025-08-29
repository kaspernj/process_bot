class ProcessBot::Process::Handlers::Custom
  attr_reader :options, :process

  def initialize(process)
    @process = process
    @options = process.options
  end

  def current_pid
    process.current_pid
  end

  def daemonize
    logger.logs "Daemonize!"

    pid = Process.fork do
      Process.daemon
      yield
    end

    Process.detach(pid) if pid
  end

  def false_value?(value)
    !value || value == "false"
  end

  def fetch(*args, **opts)
    options.fetch(*args, **opts)
  end

  def logger
    @logger ||= ProcessBot::Logger.new(options: options)
  end

  def set_option(key, value)
    raise "Unknown option for Sidekiq handler: #{key}" unless options.key?(key)

    set(key, value)
  end

  def set(*args, **opts)
    options.set(*args, **opts)
  end

  def start_command
    "bash -c 'cd #{options.fetch(:release_path)} && #{options.options.fetch(:custom_command)}'"
  end

  def stop(**_args)
    puts "Stop related processes"
    process.runner.stop_related_processes
  end
end
