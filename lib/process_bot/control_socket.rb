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
    require "socket"

    @server = TCPServer.new(port)
    options.events.call(:on_socket_opened, port: port)
  end

  def run_client_loop
    Thread.new do
      client = server.accept

      Thread.new do
        handle_client(client)
      end
    end
  end

  def handle_client(client)
    command = JSON.parse(client.gets)
    type = command.fetch("type")

    if type == "stop"
      process.stop
    else
      client.puts(JSON.generate(type: "error", message: "Unknown type: #{type}"))
    end
  end
end
