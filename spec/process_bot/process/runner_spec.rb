require "spec_helper"

describe ProcessBot::Process::Runner do
  describe "#find_sidekiq_pid" do
    it "finds the Sidekiq PID by scanning processes and comparing the PGID" do
      options = ProcessBot::Options.new(
        application: "sample_app_name",
        release_path: "/home/dev/sample_app_name/releases/20221107164955"
      )
      runner = ProcessBot::Process::Runner.new(command: nil, logger: nil, options: options)

      fake_process_output = [
        "dev       341824  0.5  0.2 2260076 367156 pts/19 Sl+  07:04   0:09 sidekiq 6.5.7 sample_app_name [0 of 25 busy]",
        "dev       342132  0.4  0.2 2326540 356624 pts/20 Sl+  07:04   0:09 sidekiq 6.5.7 sample_app_name [0 of 25 busy]"
      ]

      expect(Knj::Os).to receive(:shellcmd).with("ps aux | grep sidekiq").and_return(fake_process_output.join("\n"))
      expect(runner).to receive(:subprocess_pgid).and_return(1234).exactly(3).times
      expect(Process).to receive(:getpgid).with(341_824).and_return(4444)
      expect(Process).to receive(:getpgid).with(342_132).and_return(1234)

      runner.find_sidekiq_pid.join

      expect(runner.pid).to eq 342_132
    end

    it "parses another format" do
      options = ProcessBot::Options.new(application: "sample_app_name")
      runner = ProcessBot::Process::Runner.new(command: nil, logger: nil, options: options)

      fake_process_output = [
        "dev       342132  0.5  0.2 2260076 367156 pts/19 Sl+  07:04   0:09 sidekiq 6.5.7 sample_app_name [5 of 25 busy]"
      ]

      expect(Knj::Os).to receive(:shellcmd).with("ps aux | grep sidekiq").and_return(fake_process_output.join("\n"))
      expect(options).to receive(:application_basename).and_return("sample_app_name")
      expect(runner).to receive(:subprocess_pgid).and_return(1234).once
      expect(Process).to receive(:getpgid).with(342_132).and_return(1234)

      runner.find_sidekiq_pid.join

      expect(runner.pid).to eq 342_132
    end
  end
end
