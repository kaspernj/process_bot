require "pathname"
require "rake"
require "tempfile"

module ReleaseRakeSpecContext
  extend Rake::DSL
end

release_rake_path = File.expand_path("../lib/tasks/release.rake", __dir__)
ReleaseRakeSpecContext.module_eval(File.read(release_rake_path), release_rake_path)

RSpec.describe "ProcessBotRubygemsRelease" do
  describe "#bump_version!" do
    it "refreshes and stages Gemfile.lock with the version bump" do
      Tempfile.create(["version", ".rb"]) do |version_file|
        version_file.write(<<~RUBY)
          module ProcessBot
            VERSION = "0.1.28".freeze
          end
        RUBY
        version_file.flush

        stub_const("ReleaseRakeSpecContext::ProcessBotRubygemsRelease::VERSION_FILE", Pathname.new(version_file.path))

        release = ReleaseRakeSpecContext::ProcessBotRubygemsRelease.new

        expect(release).to receive(:run!).with("bundle", "lock").ordered
        expect(release).to receive(:run!).with("git", "add", version_file.path, "Gemfile.lock").ordered

        release.send(:bump_version!, "0.1.29")

        version_file.rewind
        expect(version_file.read).to include('VERSION = "0.1.29".freeze')
      end
    end
  end
end
