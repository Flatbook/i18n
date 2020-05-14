require 'spec_helper'

RSpec.describe I18nSonder do
  it "has a version number" do
    expect(I18nSonder::VERSION).not_to be nil
  end

  context "configuration" do
    let(:crowdin_api_key) { "api_key" }
    let(:crowdin_project_id) { "p1" }
    let(:logger) { "dummy_logger" }

    before do
      I18nSonder.configure do |config|
        config.crowdin_api_key = crowdin_api_key
        config.crowdin_project_id = crowdin_project_id
        config.logger = logger
      end
    end

    it "allows to set and get variables" do
      expect(I18nSonder.configuration.crowdin_api_key).to eq crowdin_api_key
      expect(I18nSonder.configuration.crowdin_project_id).to eq crowdin_project_id
      expect(I18nSonder.configuration.logger).to eq logger
    end

    it "allows to get logger" do
      expect(I18nSonder.logger).to be_a I18nSonder::Logger
    end
  end
end
