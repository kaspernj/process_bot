require "socket"

class ProcessBot::ClientSocket
  attr_reader :options

  def initialize(options:)
    @options = options
  end

  def client
    @client ||= Socket.tcp("localhost", options.fetch(:port).to_i, connect_timeout: connect_timeout)
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
      response_raw = read_response_with_timeout
    rescue Errno::ECONNRESET, Errno::EPIPE
      return :nil
    end

    if response_raw == :timeout
      handle_timeout
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

  def connect_timeout
    options.fetch(:connect_timeout, 2).to_f
  end

  def response_timeout
    options.fetch(:response_timeout, connect_timeout).to_f
  end

  def read_response_with_timeout
    if response_timeout.positive?
      ready = IO.select([client], nil, nil, response_timeout)
      return :timeout if ready.nil?
    end

    client.gets
  end

  def handle_timeout
    process_bot_pid = options[:process_bot_pid]
    logger.logs "Timed out waiting for response from ProcessBot"

    return unless process_bot_pid

    logger.logs "Sending KILL to ProcessBot PID #{process_bot_pid}"
    Process.kill("KILL", process_bot_pid.to_i)
  rescue Errno::ESRCH
    logger.logs "ProcessBot PID #{process_bot_pid} not running"
  end
end
