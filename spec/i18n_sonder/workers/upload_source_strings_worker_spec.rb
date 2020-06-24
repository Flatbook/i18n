require 'spec_helper'

RSpec.describe I18nSonder::Workers::UploadSourceStringsWorker do
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
    let(:has_updated_at) { true }
    let(:duplicates) { [] }

    before do
      allow(I18nSonder).to receive(:languages_to_translate).and_return(%i[fr es])
      expect(I18nSonder).to receive(:localization_provider).and_return(adapter)

      allow(model).to receive(:find).with(id).and_return(model_instance)
      allow(subject).to receive(:translation_table_name).and_return("t")
      allow(model).to receive(:joins).and_return(model)
      allow(model).to receive(:select).and_return(model)
      allow(model).to receive(:where).and_return(model)
      allow(model).to receive(:order).and_return(duplicates)
      allow(model_instance).to receive(:has_attribute?).with(:updated_at).and_return(has_updated_at)
      allow(model_instance).to receive(:id).and_return(id)
    end

    it "fetches translations, writes them to the DB, and then cleans them up" do
      expect(model_instance).to receive(:updated_at).and_return(updated)
      expect(model_instance).to receive(:attributes).and_return(attributes)
      expect(adapter).to(
          receive(:upload_attributes_to_translate)
              .with(type, id.to_s, updated, attributes_to_translate, attribute_params)
              .and_return(upload_response)
      )
      expect(logger).to receive(:info).exactly(1).times
      expect(logger).not_to receive(:error)
      subject.perform(type, id, attribute_params)
    end

    context "when model does not have an updated_at column" do
      let(:has_updated_at) { false }

      it "works" do
        expect(model_instance).to receive(:attributes).and_return(attributes)
        expect(adapter).to(
            receive(:upload_attributes_to_translate)
                .with(type, id.to_s, nil, attributes_to_translate, attribute_params)
                .and_return(upload_response)
        )
        expect(logger).to receive(:info).exactly(1).times
        expect(logger).not_to receive(:error)
        subject.perform(type, id, attribute_params)
      end
    end

    context "when object can't be found" do
      let(:model_instance) { nil }

      it "should error" do
        expect(model_instance).not_to receive(:updated_at)
        expect(model_instance).not_to receive(:attributes)
        expect(adapter).not_to receive(:upload_attributes_to_translate)

        expect(logger).not_to receive(:info)
        expect(logger).to receive(:error).exactly(1).times
        subject.perform(type, id, attribute_params)
      end
    end

    context "when uploading attributes errors" do
      let(:upload_response) { CrowdIn::Adapter::ReturnObject.new({}, error) }
      let(:translations) { { "Model" => translation1 } }

      it "should error" do
        expect(model_instance).to receive(:updated_at).and_return(updated)
        expect(model_instance).to receive(:attributes).and_return(attributes)
        expect(adapter).to(
            receive(:upload_attributes_to_translate)
                .with(type, id.to_s, updated, attributes_to_translate, attribute_params)
                .and_return(upload_response)
        )

        expect(logger).to receive(:info).exactly(1).times
        expect(logger).to receive(:error).exactly(1).times
        subject.perform(type, id, attribute_params)
      end
    end

    context "with duplicates" do
      let(:translation1) { create_translation("french val 1", "fr") }
      let(:translation2) { create_translation("french val 3", "fr") }
      let(:translation3) { create_translation("spanish val 1", "es") }
      let(:translation4) { create_translation("spanish val 3", "es") }

      before do
        expect(model_instance).to receive(:updated_at).and_return(updated)
        expect(model_instance).to receive(:attributes).and_return(attributes)
      end

      context "for all attribute values" do
        context "for all locales to translate" do
          let(:french_attrs) { { "field1" => translation1.value, "field3" => translation2.value} }
          let(:spanish_attrs) { { "field1" => translation3.value, "field3" => translation4.value} }

          it "updates all attribute values using duplicates" do
            expect(model).to receive(:order).exactly(:twice).and_return([translation1, translation3], [translation2, translation4])
            expect(model_instance).to receive(:update).with(french_attrs).exactly(:once)
            expect(model_instance).to receive(:update).with(spanish_attrs).exactly(:once)
            expect(adapter).to(
                receive(:upload_attributes_to_translate)
                    .with(type, id.to_s, updated, {}, attribute_params)
                    .and_return(upload_response)
            )

            expect(logger).to receive(:info).exactly(3).times
            subject.perform(type, id, attribute_params)
          end
        end

        context "for some locales to translate" do
          let(:french_attrs) { { "field1" => translation1.value, "field3" => translation2.value} }

          it "updates attribute values for locales with duplicates and still uploads all attribute value pairs" do
            expect(model).to receive(:order).exactly(:twice).and_return([translation1], [translation2])
            expect(model_instance).to receive(:update).with(french_attrs).exactly(:once)
            expect(adapter).to(
                receive(:upload_attributes_to_translate)
                    .with(type, id.to_s, updated, attributes_to_translate, attribute_params)
                    .and_return(upload_response)
            )

            expect(logger).to receive(:info).exactly(2).times
            subject.perform(type, id, attribute_params)
          end
        end
      end

      context "when some attribute values are duplicates" do
        context "for all locales to translate" do
          let(:french_attrs) { { "field1" => translation1.value } }
          let(:spanish_attrs) { { "field1" => translation3.value } }

          it "updates attribute values for locales with duplicates and uploads only attribute value pairs without duplicates for all locales" do
            expect(model).to receive(:order).exactly(:twice).and_return([translation1, translation3], [])
            expect(model_instance).to receive(:update).with(french_attrs).exactly(:once)
            expect(model_instance).to receive(:update).with(spanish_attrs).exactly(:once)
            expect(adapter).to(
                receive(:upload_attributes_to_translate)
                    .with(type, id.to_s, updated, attributes_to_translate.except("field1"), attribute_params)
                    .and_return(upload_response)
            )

            expect(logger).to receive(:info).exactly(3).times
            subject.perform(type, id, attribute_params)
          end
        end

        context "for some locales to translate" do
          let(:french_attrs) { { "field1" => translation1.value } }

          it "updates attribute values for locales with duplicates and uploads all attribute value pairs" do
            expect(model).to receive(:order).exactly(:twice).and_return([translation1], [])
            expect(model_instance).to receive(:update).with(french_attrs).exactly(:once)
            expect(adapter).to(
                receive(:upload_attributes_to_translate)
                    .with(type, id.to_s, updated, attributes_to_translate, attribute_params)
                    .and_return(upload_response)
            )

            expect(logger).to receive(:info).exactly(2).times
            subject.perform(type, id, attribute_params)
          end
        end
      end
    end
  end

  def create_translation(value, locale)
    t = Mobility::ActiveRecord::TextTranslation.new
    allow(t).to receive(:value).and_return(value)
    allow(t).to receive(:locale).and_return(locale)
    t
  end
end

