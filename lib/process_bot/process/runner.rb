class ProcessBot::Process::Runner
  attr_reader :command, :exit_status, :logger, :monitor, :options, :stop_time

  def initialize(command:, logger:, options:)
    @command = command
    @logger = logger
    @monitor = Monitor.new
    @options = options
    @output = []
  end

  def output(output:, type:) # rubocop:disable Lint/UnusedMethodArgument
    logger.log(output)
  end

  def run # rubocop:disable Metrics/AbcSize
    @start_time = Time.new
    stderr_reader, stderr_writer = IO.pipe

    require "pty"

    PTY.spawn(command, err: stderr_writer.fileno) do |stdout, _stdin, pid|
      @pid = pid
      logger.log "Command running with PID #{pid}: #{command}"
      options.events.call(:on_process_started, pid: pid)

      stdout_reader_thread = Thread.new do
        stdout.each_char do |chunk|
          monitor.synchronize do
            output(type: :stdout, output: chunk)
          end
        end
      rescue Errno::EIO
        # Process done
      ensure
        status = Process::Status.wait(@pid, 0)

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

      stdout_reader_thread.join
      stderr_reader_thread.join

      @stop_time = Time.new
    end
  end
end
