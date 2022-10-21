require "spec_helper"

describe ProcessBot::ClientSocket do
  it "sends a stop command to the server" do
    options = ProcessBot::Options.new
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

  it "sends a graceful stop command to the server" do
    options = ProcessBot::Options.new
    process = ProcessBot::Process.new(options)
    process.instance_variable_set(:@current_pid, 1234)

    expect(process).to receive(:graceful).and_call_original
    expect(Process).to receive(:kill).with("TSTP", 1234)
    expect(process).to receive(:wait_for_no_jobs_and_stop_sidekiq).and_call_original
    expect(process).to receive(:wait_for_no_jobs)
    expect(process).to receive(:stop)

    control_socket = ProcessBot::ControlSocket.new(options: ProcessBot::Options.new(port: 7086), process: process)
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