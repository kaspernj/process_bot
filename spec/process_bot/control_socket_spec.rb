require "spec_helper"

describe ProcessBot::ControlSocket do
  it "increases the port if already in use" do
    options1 = ProcessBot::Options.new(handler: "sidekiq")
    process1 = ProcessBot::Process.new(options1)
    control_socket1 = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 6086), process: process1)
    control_socket1.start

    options2 = ProcessBot::Options.new(handler: "sidekiq")
    process2 = ProcessBot::Process.new(options2)
    control_socket2 = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 6086), process: process2)
    control_socket2.start

    expect(control_socket1).to have_attributes(port: 6086)
    expect(control_socket2).to have_attributes(port: 6087)
  ensure
    control_socket1&.stop
    control_socket2&.stop
  end
end
