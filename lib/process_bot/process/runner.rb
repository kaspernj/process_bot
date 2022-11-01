require "knjrbfw"

class ProcessBot::Process::Runner
  attr_reader :command, :exit_status, :logger, :monitor, :options, :pid, :stop_time, :subprocess_pid

  def initialize(command:, logger:, options:)
    @command = command
    @logger = logger
    @monitor = Monitor.new
    @options = options
    @output = []
  end

  def output(output:, type:) # rubocop:disable Lint/UnusedMethodArgument
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
      logger.log "Command running with PID #{pid}: #{command}\n"

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

      find_sidekiq_pid

      stdout_reader_thread.join
      stderr_reader_thread.join

      @stop_time = Time.new
    end
  end

  def subprocess_pgid
    @subprocess_pgid ||= Process.getpgid(subprocess_pid)
  end

  def sidekiq_app_name
    options.fetch(:application)
  end

  def find_sidekiq_pid # rubocop:disable Metrics/AbcSize
    Thread.new do
      while running? && !pid
        Knj::Unix_proc.list("grep" => "sidekiq") do |process|
          cmd = process.data.fetch("cmd")

          if /sidekiq ([0-9]+\.[0-9]+\.[0-9]+) #{Regexp.escape(sidekiq_app_name)}/.match?(cmd)
            sidekiq_pid = process.data.fetch("pid").to_i

            begin
              sidekiq_pgid = Process.getpgid(sidekiq_pid)
            rescue Errno::ESRCH
              # Process no longer running
            end

            if subprocess_pgid == sidekiq_pgid
              puts "FOUND PID: #{sidekiq_pid}"

              @pid = sidekiq_pid
              options.events.call(:on_process_started, pid: pid)

              break
            else
              puts "PGID didn't match - Sidekiq: #{sidekiq_pgid} Own: #{subprocess_pgid}"
            end
          end
        end

        unless pid
          puts "Waiting 1 second before trying to find Sidekiq PID again"
          sleep 1
        end
      end
    end
  end
end
