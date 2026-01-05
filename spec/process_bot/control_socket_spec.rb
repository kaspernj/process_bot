require "spec_helper"

describe ProcessBot::ControlSocket do
  it "increases the port if already in use" do
    options1 = ProcessBot::Options.new(handler: "sidekiq")
    process1 = ProcessBot::Process.new(options1)
    control_socket1 = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 6086), process: process1)
    allow(control_socket1).to receive(:used_process_bot_ports).and_return([])
    control_socket1.start

    options2 = ProcessBot::Options.new(handler: "sidekiq")
    process2 = ProcessBot::Process.new(options2)
    control_socket2 = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 6086), process: process2)
    allow(control_socket2).to receive(:used_process_bot_ports).and_return([])

    expect(control_socket2).to receive(:actually_start_tcp_server).with("localhost", 6086).and_raise(Errno::EADDRINUSE, "Already in use")
    expect(control_socket2).to receive(:actually_start_tcp_server).with("localhost", 6087).and_call_original

    control_socket2.start

    expect(control_socket1).to have_attributes(port: 6086)
    expect(control_socket2).to have_attributes(port: 6087)
  ensure
    control_socket1&.stop
    control_socket2&.stop
  end

  it "skips ports used by other ProcessBot processes" do
    options = ProcessBot::Options.new(handler: "sidekiq")
    process = ProcessBot::Process.new(options)
    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 6086), process: process)

    allow(control_socket).to receive(:used_process_bot_ports).and_return([6086, 6087])
    allow(control_socket).to receive(:run_client_loop)

    fake_server = instance_double(TCPServer, close: true)
    expect(control_socket).to receive(:actually_start_tcp_server).with("localhost", 6088).and_return(fake_server)

    control_socket.start

    expect(control_socket).to have_attributes(port: 6088)
  ensure
    control_socket&.stop
  end
end
