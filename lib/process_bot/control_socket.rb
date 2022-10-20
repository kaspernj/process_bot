require "socket"

class ProcessBot::ControlSocket
  attr_reader :options, :process, :server

  def initialize(options:, process:)
    @options = options
    @process = process
  end

  def port
    options.fetch(:port).to_i
  end

  def start
    @server = TCPServer.new("localhost", port)
    run_client_loop

    puts "TCPServer started"

    options.events.call(:on_socket_opened, port: port)
  end

  def stop
    server.close
  end

  def run_client_loop
    Thread.new do
      client = server.accept

      Thread.new do
        handle_client(client)
      end
    end
  end

  def handle_client(client) # rubocop:disable Metrics/AbcSize
    loop do
      data = client.gets
      break if data.nil? # Client disconnected

      command = JSON.parse(data)
      command_type = command.fetch("command")

      if command_type == "graceful" || command_type == "stop"
        begin
          process.__send__(command_type)
          client.puts(JSON.generate(type: "success"))
        rescue => e # rubocop:disable Style/RescueStandardError
          client.puts(JSON.generate(type: "error", message: e.message))

          raise e
        end
      else
        client.puts(JSON.generate(type: "error", message: "Unknown command: #{command_type}"))
      end
    end
  end
end
