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

  describe "#process_bot_wait_setting" do
    it "defaults to waiting for graceful commands" do
      sidekiq_helpers_test = SidekiqHelpersTest.new
      allow(sidekiq_helpers_test).to receive(:fetch).with(:process_bot_wait_for_gracefully_stopped).and_return(nil)

      expect(sidekiq_helpers_test.process_bot_wait_setting(:graceful)).to be true
    end

    it "defaults to not waiting for graceful_no_wait commands" do
      sidekiq_helpers_test = SidekiqHelpersTest.new
      allow(sidekiq_helpers_test).to receive(:fetch).with(:process_bot_wait_for_gracefully_stopped).and_return(nil)

      expect(sidekiq_helpers_test.process_bot_wait_setting(:graceful_no_wait)).to be false
    end

    it "respects explicit wait setting" do
      sidekiq_helpers_test = SidekiqHelpersTest.new
      allow(sidekiq_helpers_test).to receive(:fetch).with(:process_bot_wait_for_gracefully_stopped).and_return(false)

      expect(sidekiq_helpers_test.process_bot_wait_setting(:graceful)).to be false
    end
  end
end
