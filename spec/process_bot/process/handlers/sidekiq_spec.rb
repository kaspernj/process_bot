require "spec_helper"

describe ProcessBot::Process::Handlers::Sidekiq do
  describe "#start_command" do
    it "uses bundle prefix if given" do
      options = ProcessBot::Options.new(
        bundle_prefix: "~/.rvm/bin/rvm 3.1.2 do",
        release_path: "/home/build/project/current"
      )
      process = ProcessBot::Process.new(options)
      sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(process)

      expect(sidekiq.start_command).to eq "bash -c 'cd /home/build/project/current && exec ~/.rvm/bin/rvm 3.1.2 do bundle exec sidekiq '"
    end

    it "passes on Sidekiq options" do
      options = ProcessBot::Options.new(
        release_path: "/home/build/project/current",
        sidekiq_environment: "production",
        sidekiq_queue: "queue1,queue2,queue3"
      )
      process = ProcessBot::Process.new(options)
      sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(process)

      expect(sidekiq.start_command).to eq "bash -c 'cd /home/build/project/current && exec bundle exec sidekiq " \
        "--environment production " \
        "--queue queue1 " \
        "--queue queue2 " \
        "--queue queue3'"
    end
  end

  describe "#graceful" do
    it "refreshes current PID when it is no longer running" do
      options = ProcessBot::Options.new(application: "sample_app", handler: "sidekiq")
      process = ProcessBot::Process.new(options)
      process.instance_variable_set(:@current_pid, 111)
      sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(process)

      fake_runner = instance_double(ProcessBot::Process::Runner)
      fake_sidekiq_process = Struct.new(:pid).new(222)
      allow(fake_runner).to receive(:related_sidekiq_processes).and_return([fake_sidekiq_process])
      allow(process).to receive(:runner).and_return(fake_runner)

      allow(Process).to receive(:getpgid).with(111).and_raise(Errno::ESRCH)
      expect(Process).to receive(:kill).with("TSTP", 222)
      allow(sidekiq).to receive(:wait_for_no_jobs_and_stop_sidekiq)

      sidekiq.graceful

      expect(process.current_pid).to eq 222
    end
  end

  describe "#graceful_no_wait" do
    it "daemonizes the graceful wait" do
      options = ProcessBot::Options.new(application: "sample_app", handler: "sidekiq")
      process = ProcessBot::Process.new(options)
      sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(process)

      allow(sidekiq).to receive_messages(ensure_current_pid?: true, send_tstp_or_return: true)
      expect(sidekiq).to receive(:daemonize)

      sidekiq.graceful_no_wait
    end
  end

  describe "#stop" do
    it "terminates all related processes when current PID is missing" do
      options = ProcessBot::Options.new(handler: "sidekiq")
      process = ProcessBot::Process.new(options)
      sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(process)

      fake_runner = instance_double(ProcessBot::Process::Runner)
      fake_processes = [Struct.new(:pid).new(111), Struct.new(:pid).new(222)]
      allow(fake_runner).to receive(:related_sidekiq_processes).and_return(fake_processes)
      allow(process).to receive(:runner).and_return(fake_runner)

      expect(Process).to receive(:kill).with("TERM", 111)
      expect(Process).to receive(:kill).with("TERM", 222)

      sidekiq.stop
    end
  end

  describe "#wait_for_sidekiq_exit" do
    it "waits until the Sidekiq process is no longer running" do
      options = ProcessBot::Options.new(handler: "sidekiq")
      process = ProcessBot::Process.new(options)
      process.instance_variable_set(:@current_pid, 123)
      sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(process)

      expect(sidekiq).to receive(:process_running?).with(123).and_return(true, false)
      expect(sidekiq).to receive(:sleep).with(1)

      sidekiq.wait_for_sidekiq_exit
    end
  end
end
