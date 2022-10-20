require "spec_helper"

describe ProcessBot::Process::Runner do
  describe "#find_sidekiq_pid" do
    it "finds the Sidekiq PID by scanning processes and comparing the PGID" do
      options = ProcessBot::Options.new(application: "gratisbyggetilbud_rails")
      runner = ProcessBot::Process::Runner.new(command: nil, logger: nil, options: options)

      fake_process_output = [
        "dev       341824  0.5  0.2 2260076 367156 pts/19 Sl+  07:04   0:09 sidekiq 6.5.7 gratisbyggetilbud_rails [0 of 25 busy]",
        "dev       342132  0.4  0.2 2326540 356624 pts/20 Sl+  07:04   0:09 sidekiq 6.5.7 gratisbyggetilbud_rails [0 of 25 busy]"
      ]

      expect(Knj::Os).to receive(:shellcmd).with("ps aux | grep sidekiq").and_return(fake_process_output.join("\n"))
      expect(runner).to receive(:subprocess_pgid).and_return(1234).exactly(3).times
      expect(Process).to receive(:getpgid).with(341_824).and_return(4444)
      expect(Process).to receive(:getpgid).with(342_132).and_return(1234)

      runner.find_sidekiq_pid.join

      expect(runner.pid).to eq 342_132
    end
  end
end
