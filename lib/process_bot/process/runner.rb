class ProcessBot::Process::Runner
  attr_reader :command, :exit_status, :logger, :monitor, :options, :output, :stop_time

  def initialize(command:, logger:, options:)
    @command = command
    @logger = logger
    @monitor = Monitor.new
    @options = options
    @output = []
  end

  def output(output:, type:)
    logger.log(output)
  end

  def run
    @start_time = Time.new
    stderr_reader, stderr_writer = IO.pipe

    require "pty"

    PTY.spawn(command, err: stderr_writer.fileno) do |stdout, stdin, pid|
      @pid = pid
      logger.log "Command running with PID #{pid}: #{command}"

      stdout_reader_thread = Thread.new do
        begin
          stdout.each_char do |chunk|
            monitor.synchronize do
              output(type: :stdout, output: chunk)
            end
          end
        rescue Errno::EIO => e
          # Process done
        ensure
          status = Process::Status.wait(@pid, 0)

          @exit_status = status.exitstatus
          stderr_writer.close
        end
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
