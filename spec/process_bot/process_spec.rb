require "spec_helper"

describe ProcessBot::Process do
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
