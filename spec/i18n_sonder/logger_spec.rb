require 'spec_helper'

RSpec.describe I18nSonder::Logger do
  subject { described_class.new }

  it "does not raise error when no logger configured" do
    expect { subject.info("a") }.not_to raise_error
    expect { subject.error("a") }.not_to raise_error
  end

  context "when a logger is set" do
    before do
      class DummyLogger
        def self.info(a)
          a
        end

        def self.error(a)
          a
        end
      end

      I18nSonder.configuration.logger = DummyLogger
    end

    it "forwards to defined logger" do
      expect(subject.info("test")).to eq "test"
      expect(subject.error("test2")).to eq "test2"
    end
  end
end

