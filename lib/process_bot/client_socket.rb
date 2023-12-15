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

  def send_command(data)
    logger.log "Sending: #{data}"
    client.puts(JSON.generate(data))
    response_raw = client.gets

    # Happens if process is interrupted
    return :nil if response_raw.nil?

    response = JSON.parse(response_raw)

    return :success if response.fetch("type") == "success"

    if response.fetch("type") == "error"
      error = RuntimeError.new("Command raised an error: #{response.fetch("message")}" )

      response.fetch("backtrace").each do |trace|
        error.backtrace.prepend(trace)
      end

      raise error
    end
  end
end
