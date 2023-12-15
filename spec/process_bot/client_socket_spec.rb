require "spec_helper"

describe ProcessBot::ClientSocket do
  it "sends a stop command to the server" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    expect(process).to receive(:stop).and_call_original
    expect(Process).to receive(:kill).with("TERM", 1234)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: 7086))

      begin
        client_socket.send_command(command: "stop")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end
  end

  it "rescues errors and forwards them with backtrace" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    rescued_error = nil

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: 7086))

      begin
        client_socket.send_command(command: "asd")
      rescue => error
        rescued_error = error
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end

    expect(rescued_error.message).to eq "Command raised an error: Unknown command: asd"
  end

  it "sends a graceful stop command to the server" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    expect(process).to receive(:graceful).and_call_original
    expect(process.handler_instance).to receive(:graceful).with({}).and_call_original
    expect(Process).to receive(:kill).with("TSTP", 1234)
    expect(process.handler_instance).to receive(:wait_for_no_jobs_and_stop_sidekiq).and_call_original
    expect(process.handler_instance).to receive(:wait_for_no_jobs)
    expect(process.handler_instance).to receive(:stop)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
    control_socket.start

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(command: "graceful", port: 7086))

      begin
        client_socket.send_command(command: "graceful")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end
  end

  it "sends a graceful stop command to the server" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

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

    client_socket_options = ProcessBot::Options.new(port: 7086, wait_for_gracefully_stopped: false)
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
  end
end
