require "knjrbfw"

class ProcessBot::Process::Runner
  attr_reader :command, :exit_status, :handler_instance, :handler_name, :logger, :monitor, :options, :pid, :stop_time, :subprocess_pid

  def initialize(command:, handler_instance:, handler_name:, logger:, options:)
    @command = command
    @handler_instance = handler_instance
    @handler_name = handler_name
    @logger = logger
    @monitor = Monitor.new
    @options = options
  end

  def output(output:, type:)
    logger.log(output, type: type)
  end

  def running?
    !stop_time
  end

  def run # rubocop:disable Metrics/AbcSize
    @start_time = Time.new
    stderr_reader, stderr_writer = IO.pipe

    require "pty"

    PTY.spawn(command, err: stderr_writer.fileno) do |stdout, _stdin, pid|
      @subprocess_pid = pid
      logger.logs "Command running with PID #{pid}: #{command}"

      stdout_reader_thread = Thread.new do
        stdout.each_char do |chunk|
          monitor.synchronize do
            output(type: :stdout, output: chunk)
          end
        end
      rescue Errno::EIO
        # Process done
      ensure
        status = Process::Status.wait(subprocess_pid, 0)

        @exit_status = status.exitstatus
        stderr_writer.close
      end

      stderr_reader_thread = Thread.new do
        stderr_reader.each_char do |chunk|
          monitor.synchronize do
            output(type: :stderr, output: chunk)
          end
        end
      end

      find_sidekiq_pid if handler_name == "sidekiq"

      stdout_reader_thread.join
      stderr_reader_thread.join

      logger.logs "Process stopped"

      @stop_time = Time.new
    end
  end

  def subprocess_pgid
    @subprocess_pgid ||= Process.getpgid(subprocess_pid)
  end

  def sidekiq_app_name
    options.fetch(:application)
  end

  def related_processes
    related_processes = []

    Knj::Unix_proc.list do |process|
      begin
        process_pgid = Process.getpgid(process.pid)
      rescue Errno::ESRCH
        # Process no longer running
      end

      related_processes << process if subprocess_pgid == process_pgid
    end

    related_processes
  end

  def related_sidekiq_processes
    related_sidekiq_processes = []

    Knj::Unix_proc.list("grep" => "sidekiq") do |process|
      cmd = process.data.fetch("cmd")

      if /sidekiq ([0-9]+\.[0-9]+\.[0-9]+) (#{options.possible_process_titles_joined_regex})/.match?(cmd)
        sidekiq_pid = process.data.fetch("pid").to_i

        begin
          sidekiq_pgid = Process.getpgid(sidekiq_pid)
        rescue Errno::ESRCH
          # Process no longer running
        end

        related_sidekiq_processes << process if subprocess_pgid == sidekiq_pgid
      end
    end

    related_sidekiq_processes
  end

  def stop_related_processes
    loop do
      processes = related_processes

      if processes.length <= 0
        logger.logs "No related processes could be found"
        break
      else
        processes.each do |process|
          logger.logs "Terminating PID #{process.pid}: #{process.data.fetch("cmd")}"
          Process.kill("TERM", process.pid)
        end

        sleep 0.5
      end
    end
  end

  def find_sidekiq_pid
    Thread.new do
      while running? && !pid
        related_sidekiq_processes.each do |related_sidekiq_process| # rubocop:disable Lint/UnreachableLoop
          puts "FOUND PID: #{related_sidekiq_process.pid}"
          @pid = related_sidekiq_process.pid
          options.events.call(:on_process_started, pid: related_sidekiq_process.pid)

          break
        end

        unless pid
          puts "Waiting 1 second before trying to find Sidekiq PID again"
          sleep 1
        end
      end
    end
  end
end
