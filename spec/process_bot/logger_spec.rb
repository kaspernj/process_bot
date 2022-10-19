require "spec_helper"

describe ProcessBot::Logger do
  describe "#logging?" do
    it "returns true if the log file path has been given in options" do
      options = ProcessBot::Options.new(log_file_path: "process_bot.log")
      logger = ProcessBot::Logger.new(options: options)

      expect(logger.logging?).to be true
    end

    it "returns false if the log file path hasnt been given in options" do
      options = ProcessBot::Options.new
      logger = ProcessBot::Logger.new(options: options)

      expect(logger.logging?).to be false
    end
  end
end
