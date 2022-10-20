require "spec_helper"

describe ProcessBot::Process do
  describe "#execute!" do
    it "sends a start command through the client socket" do
      options = ProcessBot::Options.new(command: "start")
      process = ProcessBot::Process.new(options)

      expect(process).to receive(:start_control_socket)
      expect(process).to receive(:run)
      expect(process).to receive(:stopped).and_return(true)

      process.execute!
    end

    it "sends a stop command through the client socket" do
      fake_client = instance_double(TCPSocket)
      expect(fake_client).to receive(:puts).with("{\"command\":\"stop\"}")
      expect(fake_client).to receive(:gets).with(no_args).and_return(JSON.generate(type: "success"))
      expect_any_instance_of(ProcessBot::ClientSocket).to receive(:client).at_least(:once).and_return(fake_client)

      options = ProcessBot::Options.new(command: "stop", port: 7050)

      ProcessBot::Process.new(options).execute!
    end

    it "sends a graceful command through the client socket" do
      fake_client = instance_double(TCPSocket)
      expect(fake_client).to receive(:puts).with("{\"command\":\"graceful\"}")
      expect(fake_client).to receive(:gets).with(no_args).and_return(JSON.generate(type: "success"))
      expect_any_instance_of(ProcessBot::ClientSocket).to receive(:client).at_least(:once).and_return(fake_client)

      options = ProcessBot::Options.new(command: "graceful", port: 7050)

      ProcessBot::Process.new(options).execute!
    end
  end

  describe "#update_process_title" do
    it "updates the process title with PID and port" do
      options = ProcessBot::Options.new(application: "test_app", handler: "sidekiq")
      process = ProcessBot::Process.new(options)

      options.events.call(:on_process_started, pid: 123)
      options.events.call(:on_socket_opened, port: 7052)

      expect(process.current_process_title).to eq "ProcessBot {\"application\":\"test_app\",\"handler\":\"sidekiq\",\"id\":null,\"pid\":123,\"port\":7052}"
    end
  end
end
