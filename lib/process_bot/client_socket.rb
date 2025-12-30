require "socket"

class ProcessBot::ClientSocket
  attr_reader :options

  def initialize(options:)
    @options = options
  end

  def client
    @client ||= Socket.tcp("localhost", options.fetch(:port).to_i, connect_timeout: 2)
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
      response_raw = client.gets
    rescue Errno::ECONNRESET, Errno::EPIPE
      return :nil
    end

    # Happens if process is interrupted
    return :nil if response_raw.nil?

    response = JSON.parse(response_raw)

    return :success if response.fetch("type") == "success"

    if response.fetch("type") == "error"
      error = RuntimeError.new("Command raised an error: #{response.fetch("message")}")
      error.set_backtrace(response.fetch("backtrace") + Thread.current.backtrace)

      raise error
    end
  end
end
