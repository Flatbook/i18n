require 'spec_helper'

RSpec.describe I18nSonder::Workers::UploadSourceStringsWorker do
  let(:adapter) { instance_double(CrowdIn::Adapter) }
  let(:logger) do
    stub_const 'TestLogger', Class.new
    class_double(TestLogger).as_stubbed_const(transfer_nested_constants: true)
  end

  subject do
    described_class.new.tap do |s|
      s.instance_variable_set(:@localization_provider, adapter)
      s.instance_variable_set(:@logger, logger)
    end
  end

  let(:model) do
    stub_const 'Model', Class.new
    class_double(Model).as_stubbed_const(transfer_nested_constants: true)
  end
  let(:model_instance) { instance_double(model) }
  let(:attributes) { { "field1" => "val 1", "field2" => "val 2", "field3" => "val 3" } }
  let(:id) { 1 }
  let(:type) { 'Model'}
  let(:updated) { 123 }
  let(:attribute_params) { { "field1" => {}, "field3" => { foo: true } } }
  let(:attributes_to_translate) { { "field1" => "val 1", "field3" => "val 3" } }

  let(:error) { CrowdIn::Client::Errors::Error.new(404, "not found") }

  context "#perform" do
    let(:upload_response) { CrowdIn::Adapter::ReturnObject.new(nil, nil) }

    it "fetches translations, writes them to the DB, and then cleans them up" do
      expect(model).to receive(:find).with(id).and_return(model_instance)
      expect(model_instance).to receive(:updated_at).and_return(updated)
      expect(model_instance).to receive(:attributes).and_return(attributes)
      expect(adapter).to(
          receive(:upload_attributes_to_translate)
              .with(type, id.to_s, updated.to_s, attributes_to_translate, attribute_params)
              .and_return(upload_response)
      )
      expect(logger).to receive(:info).exactly(1).times
      expect(logger).not_to receive(:error)
      subject.perform(type, id, attribute_params)
    end

    context "should error" do
      let(:translations) { { "Model" => translation1 } }
      let(:upload_response) { CrowdIn::Adapter::ReturnObject.new({}, error) }

      it "when object can't be found" do
        expect(model).to receive(:find).with(id).and_return(nil)
        expect(model_instance).not_to receive(:updated_at)
        expect(model_instance).not_to receive(:attributes)
        expect(adapter).not_to receive(:upload_attributes_to_translate)

        expect(logger).not_to receive(:info)
        expect(logger).to receive(:error).exactly(1).times
        subject.perform(type, id, attribute_params)
      end

      it "when uploading attributes errors" do
        expect(model).to receive(:find).with(id).and_return(model_instance)
        expect(model_instance).to receive(:updated_at).and_return(updated)
        expect(model_instance).to receive(:attributes).and_return(attributes)
        expect(adapter).to(
            receive(:upload_attributes_to_translate)
                .with(type, id.to_s, updated.to_s, attributes_to_translate, attribute_params)
                .and_return(upload_response)
        )

        expect(logger).to receive(:info).exactly(1).times
        expect(logger).to receive(:error).exactly(1).times
        subject.perform(type, id, attribute_params)
      end
    end
  end
end

