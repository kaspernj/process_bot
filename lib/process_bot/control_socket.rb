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
    ensure_no_duplicate_id!

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

  # Prevent a second process_bot with the same `--id` under the same
  # application from starting while the first is still alive. The
  # `start_tcp_server` loop silently drifts to a free port when the
  # requested one is in use; drift is intentional when unrelated
  # process_bots share a host, but it's a bug when a Capistrano deploy's
  # stop failed to clean up the previous release's process_bot and the
  # new release's start drifts around the zombie. Scope the match by
  # `application_basename` (derived from `release_path`) so that two
  # unrelated apps on the same host can reuse a generic id like
  # `sidekiq-main` without falsely blocking each other.
  def ensure_no_duplicate_id!
    id = options[:id]
    return if id.nil? || id.to_s.strip.empty?

    duplicates = find_duplicate_id_entries(id.to_s, safe_application_basename)
    return if duplicates.empty?

    raise duplicate_id_error_message(id, duplicates)
  end

  def find_duplicate_id_entries(id, basename)
    running_process_bot_entries.select do |entry|
      entry[:id] == id && entry[:application_basename] == basename
    end
  end

  def duplicate_id_error_message(id, duplicates)
    details = duplicates.map { |entry| "PID #{entry[:pid]} on port #{entry[:port]}" }.join(", ")
    example_port = duplicates.first[:port]
    handler = options.fetch(:handler, "custom")
    release_path = options.fetch(:release_path, "/")

    "Another process_bot with id=#{id.inspect} is already running for this application (#{details}). " \
      "Stop it (e.g. `process_bot --command stop --port #{example_port} --id #{id} " \
      "--handler #{handler} --release-path #{release_path}`) " \
      "or kill that PID before starting a new instance."
  end

  def safe_application_basename
    options.application_basename
  rescue KeyError
    nil
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
    running_process_bot_entries.filter_map { |entry| entry[:port] }.uniq
  end

  # Parsed `{application_basename:, id:, pid:, port:}` entries for every
  # running process_bot visible to `ps`, extracted from each instance's
  # JSON process title.
  def running_process_bot_entries
    entries = []

    Knj::Unix_proc.list("grep" => "ProcessBot") do |process|
      process_command = process.data.fetch("cmd")
      match = process_command.match(/ProcessBot (\{.+\})/)
      next unless match

      begin
        process_data = JSON.parse(match[1])
      rescue JSON::ParserError
        next
      end

      pid = process.data["pid"] || process.pid
      entries << {
        application_basename: process_data["application_basename"],
        id: process_data["id"]&.to_s,
        pid: pid,
        port: process_data["port"]&.to_i
      }
    end

    entries
  end
end
