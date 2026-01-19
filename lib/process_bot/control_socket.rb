require "socket"
require "json"
require "knjrbfw"

class ProcessBot::ControlSocket
  attr_reader :clients, :clients_mutex, :options, :port, :process, :server

  def initialize(options:, process:)
    @options = options
    @process = process
    @port = options.fetch(:port).to_i
    @clients = []
    @clients_mutex = Mutex.new
  end

  def logger
    @logger ||= ProcessBot::Logger.new(options: options)
  end

  def start
    start_tcp_server
    run_client_loop
    logger.logs "TCPServer started"
    options.events.call(:on_socket_opened, port: @port)
    options.events.connect(:on_log) do |event_name, output:, type:|
      broadcast_log(event_name, output: output, type: type)
    end
  end

  def start_tcp_server
    used_ports = used_process_bot_ports
    attempts = 0

    loop do
      if used_ports.include?(@port)
        @port += 1
        next
      end

      attempts += 1
      @server = actually_start_tcp_server("localhost", @port)
      break
    rescue Errno::EADDRINUSE, Errno::EADDRNOTAVAIL => e
      if attempts <= 100
        @port += 1
        next
      else
        raise e
      end
    end
  end

  def actually_start_tcp_server(host, port)
    TCPServer.new(host, port)
  end

  def stop
    server&.close
  end

  def run_client_loop
    Thread.new do
      loop do
        begin
          client = server.accept
        rescue IOError, Errno::EBADF
          break
        end

        Thread.new do
          handle_client(client)
        end
      end
    end
  end

  def handle_client(client) # rubocop:disable Metrics/AbcSize
    add_client(client)

    loop do
      data = client.gets
      break if data.nil? # Client disconnected

      command = JSON.parse(data)
      command_type = command.fetch("command")

      if command_type == "graceful" || command_type == "graceful_no_wait" || command_type == "restart" || command_type == "stop"
        begin
          unless process.accept_control_commands?
            client.puts(JSON.generate(type: "error", message: "ProcessBot is shutting down", backtrace: Thread.current.backtrace))
            break
          end

          command_options = if command["options"]
            symbolize_keys(command.fetch("options"))
          else
            {}
          end

          process.with_control_command do
            run_command(command_type, command_options, client)
          end
        rescue => e # rubocop:disable Style/RescueStandardError
          logger.error e.message
          logger.error e.backtrace

          client.puts(JSON.generate(type: "error", message: e.message, backtrace: e.backtrace))

          raise e
        end
      else
        client.puts(JSON.generate(type: "error", message: "Unknown command: #{command_type}", backtrace: Thread.current.backtrace))
      end
    end
  ensure
    remove_client(client)
    client.close unless client.closed?
  end

  def broadcast_log(_event_name, output:, type:)
    safe_output = normalize_output(output)
    payload = JSON.generate(type: "log", stream: type.to_s, output: safe_output)

    clients_snapshot.each do |client|
      client.puts(payload)
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      remove_client(client)
    end
  end

  def add_client(client)
    clients_mutex.synchronize do
      clients << client
    end
  end

  def remove_client(client)
    clients_mutex.synchronize do
      clients.delete(client)
    end
  end

  def clients_snapshot
    clients_mutex.synchronize do
      clients.dup
    end
  end

  def normalize_output(output)
    output.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
  end

  def symbolize_keys(hash)
    new_hash = {}
    hash.each do |key, value|
      next if key == "port"

      new_hash[key.to_sym] = value
    end

    new_hash
  end

  def run_command(command_type, command_options, client)
    logger.logs "Command #{command_type} with options #{command_options}"

    process.__send__(command_type, **command_options)
    client.puts(JSON.generate(type: "success"))
  end

  def used_process_bot_ports
    ports = []

    Knj::Unix_proc.list("grep" => "ProcessBot") do |process|
      process_command = process.data.fetch("cmd")
      match = process_command.match(/ProcessBot (\{.+\})/)
      next unless match

      begin
        process_data = JSON.parse(match[1])
      rescue JSON::ParserError
        next
      end

      port = process_data["port"]
      ports << port.to_i if port
    end

    ports.uniq
  end
end
