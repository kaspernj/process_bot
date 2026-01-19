require "spec_helper"
require "stringio"

describe ProcessBot::ClientSocket do
  before do
    allow_any_instance_of(ProcessBot::ControlSocket).to receive(:used_process_bot_ports).and_return([])
  end

  it "sends a stop command to the server" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    allow(Process).to receive(:getpgid).with(1234).and_return(999)
    expect(process).to receive(:stop).and_call_original
    expect(Process).to receive(:kill).with("TERM", 1234)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: control_socket.port))

      begin
        client_socket.send_command(command: "stop")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end

    expect(process).to have_attributes(stopped: true)
  end

  it "rescues errors and forwards them with backtrace" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    rescued_error = nil

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: control_socket.port))

      begin
        client_socket.send_command(command: "asd")
      rescue => e # rubocop:disable Style/RescueStandardError
        rescued_error = e
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end

    expect(rescued_error.message).to eq "Command raised an error: Unknown command: asd"
    expect(process).to have_attributes(stopped: false)
  end

  it "sends a graceful stop command to the server" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    allow(Process).to receive(:getpgid).with(1234).and_return(999)
    expect(process).to receive(:graceful).and_call_original
    expect(process.handler_instance).to receive(:graceful).and_call_original
    expect(Process).to receive(:kill).with("TSTP", 1234)
    expect(process.handler_instance).to receive(:wait_for_no_jobs_and_stop_sidekiq).and_call_original
    expect(process.handler_instance).to receive(:wait_for_no_jobs)
    expect(process.handler_instance).to receive(:stop)
    expect(process.handler_instance).to receive(:wait_for_sidekiq_exit)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(command: "graceful", port: control_socket.port))

      begin
        client_socket.send_command(command: "graceful")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end

    expect(process).to have_attributes(stopped: true)
  end

  it "sends a graceful_no_wait command to the server" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    allow(Process).to receive(:getpgid).with(1234).and_return(999)
    expect(process).to receive(:graceful_no_wait).and_call_original
    expect(process.handler_instance).to receive(:graceful_no_wait).and_call_original
    expect(Process).to receive(:kill).with("TSTP", 1234)
    expect(Process).to receive(:fork).and_return(4321)
    expect(Process).to receive(:detach).with(4321)
    expect(process.handler_instance).not_to receive(:wait_for_no_jobs_and_stop_sidekiq)
    expect(process.handler_instance).not_to receive(:wait_for_no_jobs)
    expect(process.handler_instance).not_to receive(:stop)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: control_socket.port))

    begin
      begin
        client_socket.send_command(command: "graceful_no_wait")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end

    expect(process).to have_attributes(stopped: true)
  end

  it "sends a restart command to the server" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)

    expect(process).to receive(:restart)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: control_socket.port))

      begin
        client_socket.send_command(command: "restart")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end
  end

  it "returns nil when the socket is reset while waiting for a response" do
    fake_client = instance_double(TCPSocket)
    allow(fake_client).to receive(:puts).and_return(true)
    allow(fake_client).to receive(:gets).and_raise(Errno::ECONNRESET)
    allow(fake_client).to receive(:close)

    allow_any_instance_of(ProcessBot::ClientSocket).to receive(:client).and_return(fake_client)

    client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: 7050))

    begin
      result = client_socket.send_command(command: "graceful")
    ensure
      client_socket.close
    end

    expect(result).to eq :nil
  end

  it "streams log output to stdout and stderr while waiting for success" do
    fake_client = instance_double(TCPSocket)

    expect(fake_client).to receive(:puts).with(JSON.generate(command: "stop")).and_return(true)
    expect(fake_client).to receive(:gets).and_return(
      "#{JSON.generate(type: "log", stream: "stdout", output: "hello")}\n",
      "#{JSON.generate(type: "log", stream: "stderr", output: "oops")}\n",
      "#{JSON.generate(type: "success")}\n"
    )
    expect(fake_client).to receive(:close)

    expect_any_instance_of(ProcessBot::ClientSocket).to receive(:client).at_least(:once).and_return(fake_client)

    result = nil

    expect do
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: 7050))

      begin
        result = client_socket.send_command(command: "stop")
      ensure
        client_socket.close
      end
    end.to output("hello").to_stdout.and output("oops").to_stderr

    expect(result).to eq :success
  end

  it "rejects new commands when ProcessBot is shutting down" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@accept_control_commands, false)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: control_socket.port))

      begin
        expect { client_socket.send_command(command: "stop") }
          .to raise_error(RuntimeError, "Command raised an error: ProcessBot is shutting down")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end
  end

  it "accepts multiple client connections" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    allow(Process).to receive(:getpgid).with(1234).and_return(999)
    expect(process).to receive(:stop).twice.and_call_original
    expect(Process).to receive(:kill).with("TERM", 1234).twice

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    begin
      2.times do
        client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: control_socket.port))

        begin
          client_socket.send_command(command: "stop")
        ensure
          client_socket.close
        end
      end
    ensure
      control_socket.stop
    end

    expect(process).to have_attributes(stopped: true)
  end

  it "broadcasts log messages to connected clients" do
    options = ProcessBot::Options.new(handler: "sidekiq", log: true, port: 7087)
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    expect(Process).to receive(:getpgid).with(1234).and_return(999)
    expect(process).to receive(:stop).and_call_original
    expect(Process).to receive(:kill).with("TERM", 1234)

    control_socket = ProcessBot::ControlSocket.new(options: options, process: process)
    control_socket.start

    client = nil
    log_messages = []

    begin
      client = TCPSocket.new("localhost", control_socket.port)
      client.puts(JSON.generate(command: "stop"))

      loop do
        response_raw = client.gets
        break if response_raw.nil?

        response = JSON.parse(response_raw)

        if response["type"] == "log"
          log_messages << response
        elsif response["type"] == "success"
          break
        end
      end
    ensure
      client&.close
      control_socket.stop
    end

    expect(log_messages).not_to be_empty
    expect(log_messages.any? { |message| message["output"].include?("Command stop") }).to be true
  end

  it "broadcasts log messages with invalid bytes sanitized" do
    options = ProcessBot::Options.new(handler: "sidekiq", log: true, port: 7088)
    process = ProcessBot::Process.new(options)

    control_socket = ProcessBot::ControlSocket.new(options: options, process: process)
    control_socket.start

    client = nil

    begin
      client = TCPSocket.new("localhost", control_socket.port)
      invalid_output = "ok\xFF".force_encoding("UTF-8")

      50.times do
        break if control_socket.clients_snapshot.any?

        sleep 0.01
      end

      control_socket.broadcast_log(:on_log, output: invalid_output, type: :stdout)

      response = JSON.parse(client.gets)

      expect(response.fetch("type")).to eq "log"
      expect(response.fetch("output")).to eq "ok?"
    ensure
      client&.close
      control_socket.stop
    end
  end
end
