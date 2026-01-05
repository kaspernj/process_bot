require "spec_helper"

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

  it "sends a graceful stop command to the server with 'wait_for_gracefully_stopped'" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    allow(Process).to receive(:getpgid).with(1234).and_return(999)
    expect(process).to receive(:graceful).with(wait_for_gracefully_stopped: false).and_call_original
    expect(process.handler_instance).to receive(:graceful).with(wait_for_gracefully_stopped: false).and_call_original
    expect(Process).to receive(:kill).with("TSTP", 1234)
    expect(Process).to receive(:fork).and_return(4321)
    expect(Process).to receive(:detach).with(4321)
    expect(process.handler_instance).not_to receive(:wait_for_no_jobs_and_stop_sidekiq)
    expect(process.handler_instance).not_to receive(:wait_for_no_jobs)
    expect(process.handler_instance).not_to receive(:stop)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    client_socket_options = ProcessBot::Options.new(port: control_socket.port, wait_for_gracefully_stopped: false)
    client_socket = ProcessBot::ClientSocket.new(options: client_socket_options)

    begin
      begin
        client_socket.send_command(command: "graceful", options: client_socket_options.options)
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
    expect(process).to receive(:graceful).with(wait_for_gracefully_stopped: false).and_call_original
    expect(process.handler_instance).to receive(:graceful).with(wait_for_gracefully_stopped: false).and_call_original
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
end
