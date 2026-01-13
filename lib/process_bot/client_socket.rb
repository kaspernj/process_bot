require "json"
require "socket"

class ProcessBot::ClientSocket
  attr_reader :options

  def initialize(options:)
    @options = options
  end

  def client
    return @client if @client

    logger.logs "Connecting to process on port #{options.fetch(:port)}"
    @client = Socket.tcp("localhost", options.fetch(:port).to_i, connect_timeout: 2)
  end

  def close
    client.close
  end

  def logger
    @logger ||= ProcessBot::Logger.new(options: options)
  end

  def send_command(data) # rubocop:disable Metrics/AbcSize
    logger.logs "Sending: #{data}"
    begin
      client.puts(JSON.generate(data))
      loop do
        response_raw = client.gets
        return :nil if response_raw.nil?

        response = JSON.parse(response_raw)

        case response.fetch("type")
        when "log"
          write_log_output(response)
        when "success"
          return :success
        when "error"
          error = RuntimeError.new("Command raised an error: #{response.fetch("message")}")
          error.set_backtrace(response.fetch("backtrace") + Thread.current.backtrace)

          raise error
        else
          raise "Unknown response type: #{response.fetch("type")}"
        end
      end
    rescue Errno::ECONNRESET, Errno::EPIPE
      :nil
    end
  end

  def write_log_output(response)
    output = response["output"].to_s
    stream = response.fetch("stream", "stdout")

    if stream == "stderr"
      $stderr.print output
    else
      $stdout.print output
    end
  end
end
