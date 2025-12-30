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

  def process_running?(pid)
    return false unless pid

    Process.getpgid(pid)
    true
  rescue Errno::ESRCH
    false
  end

  def refresh_current_pid
    return current_pid if process_running?(current_pid)

    related_sidekiq_processes = process.runner.related_sidekiq_processes
    if related_sidekiq_processes.empty?
      logger.logs "No related Sidekiq processes found while refreshing PID"
      return nil
    end

    new_pid = related_sidekiq_processes.first.pid
    logger.logs "Refreshing Sidekiq PID from #{current_pid || 'nil'} to #{new_pid}"
    options.events.call(:on_process_started, pid: new_pid)
    new_pid
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

  def graceful(**args)
    wait_for_gracefully_stopped = args.fetch(:wait_for_gracefully_stopped, true)
    process.set_stopped

    unless current_pid
      warn "Sidekiq not running with a PID"
      return
    end

    unless refresh_current_pid
      logger.logs "Sidekiq PID not running and no replacement found - nothing to stop"
      return
    end

    begin
      Process.kill("TSTP", current_pid)
    rescue Errno::ESRCH
      logger.logs "Sidekiq PID #{current_pid} disappeared before TSTP"
      return
    end

    if false_value?(wait_for_gracefully_stopped)
      logger.logs "Dont wait for gracefully stopped - doing that in fork..."

      daemonize do
        wait_for_no_jobs_and_stop_sidekiq
        exit
      end
    else
      logger.logs "Wait for gracefully stopped..."
      wait_for_no_jobs_and_stop_sidekiq
    end
  end

  def stop(**_args)
    refresh_current_pid

    if current_pid
      begin
        Process.kill("TERM", current_pid)
      rescue Errno::ESRCH
        logger.logs "Sidekiq PID #{current_pid} is not running - nothing to stop"
      end
    else
      related_sidekiq_processes = process.runner.related_sidekiq_processes

      if related_sidekiq_processes.empty?
        logger.error "#{handler_name} didn't have any processes running"
      else
        related_sidekiq_processes.each do |related_sidekiq_process|
          begin
            Process.kill("TERM", related_sidekiq_process.pid)
          rescue Errno::ESRCH
            logger.logs "Related Sidekiq PID #{related_sidekiq_process.pid} is not running"
          end
        end
      end
    end
  end

  def wait_for_no_jobs # rubocop:disable Metrics/AbcSize
    loop do
      found_process = false

      unless refresh_current_pid
        logger.logs "Sidekiq PID not running while waiting for jobs"
        return
      end

      Knj::Unix_proc.list("grep" => current_pid) do |process|
        process_command = process.data.fetch("cmd")
        process_pid = process.data.fetch("pid").to_i
        next unless process_pid == current_pid

        found_process = true
        sidekiq_regex = /\Asidekiq (\d+).(\d+).(\d+) (#{options.possible_process_titles_joined_regex}) \[(\d+) of (\d+)(\]|) (.+?)(\]|)\Z/
        match = process_command.match(sidekiq_regex)
        raise "Couldnt match Sidekiq command: #{process_command} with Sidekiq regex: #{sidekiq_regex}" unless match

        running_jobs = match[5].to_i

        logger.logs "running_jobs: #{running_jobs}"

        return if running_jobs.zero? # rubocop:disable Lint/NonLocalExitFromIterator
      end

      unless found_process
        logger.logs "Couldn't find running process with PID #{current_pid}"
        return
      end

      sleep 1
    end
  end

  def wait_for_no_jobs_and_stop_sidekiq
    logger.logs "Wait for no jobs and Stop sidekiq"
    wait_for_no_jobs
    stop
  end
end
