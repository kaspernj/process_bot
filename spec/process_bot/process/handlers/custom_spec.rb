require "spec_helper"
require "process_bot/process/handlers/custom"

describe ProcessBot::Process::Handlers::Custom do
  describe "#stop" do
    it "stops related processes through the active runner" do
      process = ProcessBot::Process.new(ProcessBot::Options.new(handler: "custom"))
      custom = ProcessBot::Process::Handlers::Custom.new(process)
      fake_runner = instance_double(ProcessBot::Process::Runner)

      expect(process).to receive(:active_runner!).and_return(fake_runner)
      expect(fake_runner).to receive(:stop_related_processes)

      custom.stop
    end
  end
end
