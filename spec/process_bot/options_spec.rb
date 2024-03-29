require "spec_helper"

describe ProcessBot::Options do
  describe "#application_basename" do
    it "returns the application basename from the release path (releases)" do
      options = ProcessBot::Options.new(release_path: "/home/dev/peak-flow-production/releases/20221107164955")

      expect(options.application_basename).to eq "peak-flow-production"
    end

    it "returns the application basename from the release path (current)" do
      options = ProcessBot::Options.new(release_path: "/home/dev/peak-flow-production/current")

      expect(options.application_basename).to eq "peak-flow-production"
    end
  end
end
