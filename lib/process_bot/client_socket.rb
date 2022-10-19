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

  def send_command(data)
    puts "Sending command"
    client.puts(JSON.generate(data))

    puts "Getting response"
    response = JSON.parse(client.gets)

    if response.fetch("type") == "success"
      true
    elsif response.fetch("type") == "error"
      raise "Command raised an error: #{response.fetch("message")}"
    end
  end
end
