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

  describe "#wait_for_no_jobs_and_stop_sidekiq" do
    it "waits for Sidekiq to have no running jobs and then terminates it" do
      fake_process_output = [
        "dev       341824  0.5  0.2 2260076 367156 pts/19 Sl+  07:04   0:09 sidekiq 6.5.7 gratisbyggetilbud_rails [0 of 25 busy]",
        "dev       342132  0.4  0.2 2326540 356624 pts/20 Sl+  07:04   0:09 sidekiq 6.5.7 gratisbyggetilbud_rails [0 of 25 busy]"
      ]

      expect(Knj::Os).to receive(:shellcmd).with("ps aux | grep 342132").and_return(fake_process_output.join("\n"))
      expect(Process).to receive(:kill).with("TERM", 342_132)

      options = ProcessBot::Options.new(application: "gratisbyggetilbud_rails")
      process = ProcessBot::Process.new(options)
      process.instance_variable_set(:@current_pid, 342_132)
      process.wait_for_no_jobs_and_stop_sidekiq
    end
  end
end
