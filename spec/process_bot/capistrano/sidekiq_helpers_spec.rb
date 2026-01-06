require "spec_helper"

class SidekiqHelpersTest
  include ProcessBot::Capistrano::SidekiqHelpers
end

describe ProcessBot::Capistrano::SidekiqHelpers do
  describe "#parse_process_bot_process_from_ps" do
    it "parses the output and returns a list of processes" do
      sample_output = " 309553 pts/37   Ssl+   0:01 " \
        'ProcessBot {"application":"sample_app_name","handler":"sidekiq","id":"sidekiq-20221019133124-0","pid":310050,"port":7050}' \
        "\n " \
        "309692 pts/38   Ssl+   0:01 " \
        'ProcessBot {"application":"sample_app_name","handler":"sidekiq","id":"sidekiq-20221019133124-1","pid":310215,"port":7051}'

      sidekiq_helpers_test = SidekiqHelpersTest.new
      result = sidekiq_helpers_test.parse_process_bot_process_from_ps(sample_output)

      expect(result).to eq [
        {
          "application" => "sample_app_name",
          "handler" => "sidekiq",
          "id" => "sidekiq-20221019133124-0",
          "pid" => 310_050,
          "port" => 7050,
          "process_bot_pid" => "309553"
        },
        {
          "application" => "sample_app_name",
          "handler" => "sidekiq",
          "id" => "sidekiq-20221019133124-1",
          "pid" => 310_215,
          "port" => 7051,
          "process_bot_pid" => "309692"
        }
      ]
    end
  end

  describe "#process_bot_sidekiq_index" do
    it "parses the process index from the ProcessBot id" do
      sidekiq_helpers_test = SidekiqHelpersTest.new

      expect(sidekiq_helpers_test.process_bot_sidekiq_index("id" => "sidekiq-20221019133124-3")).to eq 3
    end

    it "returns nil when the id does not include an index" do
      sidekiq_helpers_test = SidekiqHelpersTest.new

      expect(sidekiq_helpers_test.process_bot_sidekiq_index("id" => "sidekiq-no-index")).to be_nil
    end
  end

  describe "#sidekiq_command_graceful?" do
    it "detects graceful shutdown commands" do
      sidekiq_helpers_test = SidekiqHelpersTest.new

      expect(sidekiq_helpers_test.sidekiq_command_graceful?("sidekiq 6.5.7 app [3 of 25 stopping]")).to be true
      expect(sidekiq_helpers_test.sidekiq_command_graceful?("sidekiq 6.5.7 app [3 of 25 quiet]")).to be true
    end

    it "returns false for normal busy output" do
      sidekiq_helpers_test = SidekiqHelpersTest.new

      expect(sidekiq_helpers_test.sidekiq_command_graceful?("sidekiq 6.5.7 app [0 of 25 busy]")).to be false
    end
  end

  describe "#missing_sidekiq_indexes" do
    it "returns desired indexes excluding active ones" do
      sidekiq_helpers_test = SidekiqHelpersTest.new

      expect(sidekiq_helpers_test.missing_sidekiq_indexes(3, [1])).to eq [0, 2]
    end
  end
end
