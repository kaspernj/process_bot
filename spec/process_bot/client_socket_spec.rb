require "spec_helper"

describe ProcessBot::ClientSocket do
  it "sends a stop command to the server" do
    fake_process = instance_double(ProcessBot::Process)
    expect(fake_process).to receive(:stop)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: fake_process)
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

  it "sends a graceful stop command to the server" do
    fake_process = instance_double(ProcessBot::Process)
    expect(fake_process).to receive(:graceful)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: fake_process)
    control_socket.start

    begin
      client_socket = ProcessBot::ClientSocket.new(options: ProcessBot::Options.new(port: 7086))

      begin
        client_socket.send_command(command: "graceful")
      ensure
        client_socket.close
      end
    ensure
      control_socket.stop
    end
  end
end
