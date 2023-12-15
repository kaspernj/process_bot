require "socket"

class ProcessBot::ClientSocket
  attr_reader :options

  def initialize(options:)
    @options = options
  end

  def client
    @client ||= TCPSocket.new("localhost", options.fetch(:port).to_i)
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

    raise "Command raised an error: #{response.fetch("message")}" if response.fetch("type") == "error"
  end
end
