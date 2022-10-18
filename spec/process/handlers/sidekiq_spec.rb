require "spec_helper"

describe ProcessBot::Process::Handlers::Sidekiq do
  it "uses bundle prefix if given" do
    options = ProcessBot::Options.new(
      bundle_prefix: "~/.rvm/bin/rvm 3.1.2 do"
    )
    sidekiq = ProcessBot::Process::Handlers::Sidekiq.new(options)

    expect(sidekiq.command).to eq "~/.rvm/bin/rvm 3.1.2 do bundle exec sidekiq "
  end
end
