require "socket"

class ProcessBot::ControlSocket
  attr_reader :options, :port, :process, :server

  def initialize(options:, process:)
    @options = options
    @process = process
    @port = options.fetch(:port).to_i
  end

  def logger
    @logger ||= ProcessBot::Logger.new(options: options)
  end

  def start
    start_tcp_server
    run_client_loop
    logger.logs "TCPServer started"
    options.events.call(:on_socket_opened, port: @port)
  end

  def start_tcp_server
    tries ||= 0
    tries += 1
    @server = actually_start_tcp_server("localhost", @port)
  rescue Errno::EADDRINUSE, Errno::EADDRNOTAVAIL => e
    if tries <= 100
      @port += 1
      retry
    else
      raise e
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
          command_options = if command["options"]
            symbolize_keys(command.fetch("options"))
          else
            {}
          end

          logger.logs "Command #{command_type} with options #{command_options}"

          if command_type == "graceful" && !wait_for_gracefully_stopped?(command_options)
            Thread.new do
              begin
                process.__send__(command_type, **command_options)
              rescue => e # rubocop:disable Style/RescueStandardError
                logger.error e.message
                logger.error e.backtrace
              end
            end
            client.puts(JSON.generate(type: "success"))
          else
            process.__send__(command_type, **command_options)
            client.puts(JSON.generate(type: "success"))
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
  end

  def symbolize_keys(hash)
    new_hash = {}
    hash.each do |key, value|
      next if key == "port"

      new_hash[key.to_sym] = value
    end

    new_hash
  end

  def wait_for_gracefully_stopped?(command_options)
    return true unless command_options.key?(:wait_for_gracefully_stopped)

    value = command_options[:wait_for_gracefully_stopped]
    normalized = value.to_s.strip.downcase
    return false if value == false || normalized == "false" || normalized == "0"

    true
  end
end
