require "spec_helper"

describe ProcessBot::Options do
  describe "#application_basename" do
    it "returns the application basename from the release path (releases)" do
      options = ProcessBot::Options.new(release_path: "/home/dev/sample_app_name/releases/20221107164955")

      expect(options.application_basename).to eq "sample_app_name"
    end

    it "returns the application basename from the release path (current)" do
      options = ProcessBot::Options.new(release_path: "/home/dev/sample_app_name/current")

      expect(options.application_basename).to eq "sample_app_name"
    end
  end
end
