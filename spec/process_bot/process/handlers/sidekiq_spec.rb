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
end
