require "spec_helper"

describe ProcessBot::Process::Handlers::Sidekiq do
  it "uses bundle prefix if given" do
    options = ProcessBot::Options.new(
      bundle_prefix: "~/.rvm/bin/rvm 3.1.2 do",
      release_path: "/home/build/project/current"
    )
    sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(options)

    expect(sidekiq.command).to eq "bash -c 'cd /home/build/project/current && ~/.rvm/bin/rvm 3.1.2 do bundle exec sidekiq '"
  end

  it "passes on Sidekiq options" do
    options = ProcessBot::Options.new(
      release_path: "/home/build/project/current",
      sidekiq_environment: "production",
      sidekiq_queue: "queue1,queue2,queue3"
    )
    sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(options)

    expect(sidekiq.command).to eq "bash -c 'cd /home/build/project/current && bundle exec sidekiq " \
      "--environment production " \
      "--queue queue1 " \
      "--queue queue2 " \
      "--queue queue3'"
  end
end
