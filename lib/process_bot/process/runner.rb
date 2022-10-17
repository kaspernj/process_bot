class ProcessBot::Process::Runner
  attr_reader :command, :exit_status, :stop_time

  def initialize(command:)
    @command = command
    @output = []
  end

  def on_output(&blk)
    puts "Setting on output for: #{command}"
    @on_output_callback = blk
  end

  def run
    @start_time = Time.new
    stderr_reader, stderr_writer = IO.pipe

    PTY.spawn(command, err: stderr_writer.fileno) do |stdout, stdin, pid|
      @pid = pid

      puts "Command running: #{command} - #{stdout.class.name}"

      stdout_reader_thread = Thread.new do
        begin
          stdout.each_char do |chunk|
            monitor.synchronize do
              out = {type: :stdout, output: chunk}
              output << out
              on_output_callback&.call(out)
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
            out = {type: :stderr, output: chunk}
            output << out
            on_output_callback&.call(out)
          end
        end
      end

      stdout_reader_thread.join
      stderr_reader_thread.join

      @stop_time = Time.new
    end
  end
end
