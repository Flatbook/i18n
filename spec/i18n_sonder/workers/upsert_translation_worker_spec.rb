require 'spec_helper'

RSpec.describe I18nSonder::Workers::UpsertTranslationWorker do
  let(:adapter) { instance_double(CrowdIn::Adapter) }
  let(:logger) do
    stub_const 'TestLogger', Class.new
    class_double(TestLogger).as_stubbed_const(transfer_nested_constants: true)
  end

  subject do
    described_class.new.tap do |s|
      s.instance_variable_set(:@logger, logger)
    end
  end

  let(:language) { "fr" }
  let(:translation_id) { "123" }
  let(:source_string_id) { "234" }

  let(:model) do
    stub_const 'Model', Class.new
    class_double(Model).as_stubbed_const(transfer_nested_constants: true)
  end
  let(:model_instance) { instance_double(model) }
  let(:translation) {
    {
      "source_text" => { "Model" => { "1" => { "field1" => "source1" } } },
      "translation" => { "Model" => { "1" => { "field1" => "translation1" } } }
    }
  }
  let(:translation_response) { CrowdIn::Adapter::ReturnObject.new(translation, nil) }

  let(:error) { CrowdIn::Client::Errors::Error.new(404, "not found") }

  context "#perform" do
    before do
      expect(I18nSonder).to receive(:localization_provider).and_return(adapter)
    end

    it "fetches translation, and writes them to the DB" do
      expect(adapter).to(
        receive(:translation_by_id)
          .with(translation_id, source_string_id)
          .and_return(translation_response)
      )
      expect(model).to receive(:where).with("field1 = ?", "source1").and_return([{ id: 1 }])
      expect(model).to receive(:update).with(1, translation.dig('translation', 'Model', '1'))
      expect(logger).to receive(:info).exactly(1).times
      expect(logger).not_to receive(:error)
      subject.perform(language, translation_id, source_string_id)
    end

    it "logs error on failure" do
      expect(adapter).to(
        receive(:translation_by_id)
          .with(translation_id, source_string_id)
          .and_return(CrowdIn::Adapter::ReturnObject.new({}, error))
      )
      expect(model).not_to receive(:update)
      expect(logger).not_to receive(:info)
      expect(logger).to receive(:error).twice
      subject.perform(language, translation_id, source_string_id)
    end
  end
end
