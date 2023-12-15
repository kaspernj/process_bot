class ProcessBot::Process::Handlers::Sidekiq
  attr_reader :options, :process

  def initialize(process)
    @process = process
    @options = process.options
  end

  def current_pid
    process.current_pid
  end

  def daemonize
    logger.log "DAEMONIZE!"

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

  def start_command # rubocop:disable Metrics/AbcSize
    args = []

    options.options.each do |key, value|
      next unless (match = key.to_s.match(/\Asidekiq_(.+)\Z/))

      sidekiq_key = match[1]

      if sidekiq_key == "queue"
        value.split(",").each do |queue|
          args.push "--queue #{queue}"
        end
      else
        args.push "--#{sidekiq_key} #{value}"
      end
    end

    command = "bash -c 'cd #{options.fetch(:release_path)} && exec "
    command << "#{options.fetch(:bundle_prefix)} " if options.present?(:bundle_prefix)
    command << "bundle exec sidekiq #{args.compact.join(' ')}"
    command << "'"
    command
  end

  def graceful(args = {})
    wait_for_gracefully_stopped = args[:wait_for_gracefully_stopped]
    @stopped = true

    unless current_pid
      warn "#{handler_name} not running with a PID"
      return
    end

    Process.kill("TSTP", current_pid)

    logger.log "wait_for_gracefully_stopped: #{wait_for_gracefully_stopped}"

    if false_value?(wait_for_gracefully_stopped)
      logger.log "Dont wait for gracefully stopped!"

      daemonize do
        wait_for_no_jobs_and_stop_sidekiq
        exit
      end
    else
      logger.log "WAIT FOR GRACEFULLY STOPPED!"

      wait_for_no_jobs_and_stop_sidekiq
    end
  end

  def stop(_args = {})
    @stopped = true

    unless current_pid
      warn "#{handler_name} not running with a PID"
      return
    end

    Process.kill("TERM", current_pid)
  end

  def wait_for_no_jobs # rubocop:disable Metrics/AbcSize
    loop do
      found_process = false

      Knj::Unix_proc.list("grep" => current_pid) do |process|
        process_command = process.data.fetch("cmd")
        process_pid = process.data.fetch("pid").to_i
        next unless process_pid == current_pid

        found_process = true
        sidekiq_regex = /\Asidekiq (\d+).(\d+).(\d+) (#{options.possible_process_titles_joined_regex}) \[(\d+) of (\d+)(\]|) (.+?)(\]|)\Z/
        match = process_command.match(sidekiq_regex)
        raise "Couldnt match Sidekiq command: #{process_command} with Sidekiq regex: #{sidekiq_regex}" unless match

        running_jobs = match[5].to_i

        logger.log "running_jobs: #{running_jobs}"

        return if running_jobs.zero? # rubocop:disable Lint/NonLocalExitFromIterator
      end

      raise "Couldn't find running process with PID #{current_pid}" unless found_process

      sleep 1
    end
  end

  def wait_for_no_jobs_and_stop_sidekiq
    logger.log "Wait for no jobs and Stop sidekiq"

    wait_for_no_jobs
    stop
  end
end
