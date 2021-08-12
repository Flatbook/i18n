require 'spec_helper'

RSpec.describe I18nSonder::Workers::SyncTranslations do
  let(:adapter) { instance_double(CrowdIn::Adapter) }
  let(:logger) do
    stub_const 'TestLogger', Class.new
    class_double(TestLogger).as_stubbed_const(transfer_nested_constants: true)
  end

  subject do
    Class.new.tap do |s|
      s.extend(I18nSonder::Workers::SyncTranslations)
      s.instance_variable_set(:@logger, logger)
    end
  end

  let(:model) do
    stub_const 'Model', Class.new
    class_double(Model).as_stubbed_const(transfer_nested_constants: true)
  end
  let(:another_model) do
    stub_const 'AnotherModel', Class.new
    class_double(AnotherModel).as_stubbed_const(transfer_nested_constants: true)
  end
  let(:translation1) { { "1" => { "field1" => "val 3", "field2" => "val 2" } } }
  let(:translation2) { { "3" => { "field1" => "val 3", "field2" => "val 2" } } }
  let(:translation3) { { "4" => { "field3" => "val 3", "field4" => "val 2" } } }
  let(:translations) { { "Model" => translation1.merge(translation2), "AnotherModel" => translation3 } }
  let(:successful_syncs) { { "Model" => { "1" => [:fr],  "3" => [:fr] }, "AnotherModel" => { "4" => [:fr] } } }
  let(:error) { CrowdIn::Client::Errors::Error.new(404, "not found") }
  let(:batch_size) { 500 }

  context "#sync" do
    let(:translations_response) { CrowdIn::Adapter::ReturnObject.new(translations, nil) }
    let(:cleanup_response) { CrowdIn::Adapter::ReturnObject.new(nil, nil) }

    before do
      I18n.available_locales = [:en, :fr]
      I18n.default_locale = :en
      expect(I18nSonder).to receive(:localization_provider).and_return(adapter)
    end

    context "all translations" do
      it "fetches translations, and writes them to the DB" do
        expect(adapter).to receive(:translations).with('fr', batch_size).and_yield(translations_response)
        expect(model).to receive(:update).with('1', translation1['1'])
        expect(model).to receive(:update).with('3', translation2['3'])
        expect(another_model).to receive(:update).with('4', translations['AnotherModel']['4'])
        expect(adapter).not_to receive(:cleanup_translations)
        expect(logger).to receive(:info).exactly(4).times
        expect(logger).not_to receive(:error)
        subject.sync(approved_translations_only: false)
      end
    end

    context "approved translations only" do
      it "fetches translations, and writes them to the DB, and then cleans up successful syncs" do
        expect(adapter).to receive(:approved_translations).with('fr', batch_size).and_yield(translations_response)
        expect(model).to receive(:update).with('1', translation1['1'])
        expect(model).to receive(:update).with('3', translation2['3'])
        expect(another_model).to receive(:update).with('4', translations['AnotherModel']['4'])
        expect(adapter).to receive(:cleanup_translations).with(successful_syncs, [:fr]).and_return(cleanup_response)
        expect(logger).to receive(:info).exactly(5).times
        expect(logger).not_to receive(:error)
        subject.sync(approved_translations_only: true)
      end
    end

    context "with errors on fetching transaltions" do
      let(:translations) { { "Model" => translation1 } }

      context "with no valid translations" do
        let(:translations_response) { CrowdIn::Adapter::ReturnObject.new({}, error) }

        it "does not write translations if adapter returns error with empty translations" do
          expect(adapter).to receive(:translations).with('fr', batch_size).and_yield(translations_response)
          expect(model).not_to receive(:update)
          expect(logger).to receive(:info).exactly(1).times
          expect(logger).to receive(:error).exactly(1).times
          subject.sync(approved_translations_only: false)
        end
      end

      context "with valid translations" do
        let(:translations_response) { CrowdIn::Adapter::ReturnObject.new(translations, error) }

        it "writes valid translations and logs for error" do
          expect(adapter).to receive(:translations).with('fr', batch_size).and_yield(translations_response)
          expect(model).to receive(:update).with('1', translation1['1'])
          expect(logger).to receive(:info).exactly(2).times
          expect(logger).to receive(:error).exactly(1).times
          subject.sync(approved_translations_only: false)
        end
      end
    end

    context "with errors on writing transaltions" do
      let(:error) { StandardError.new("error") }

      it "doesn't cleanup any translations and logs writing error for ony the failed update" do
        expect(adapter).to receive(:translations).with('fr', batch_size).and_yield(translations_response)

        expect(model).to receive(:update).with('1', translation1['1'])
        expect(model).to receive(:update).with('3', translation2['3']).and_raise(error)
        expect(another_model).to receive(:update).with('4', translations['AnotherModel']['4'])

        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with("[Class] #{error}").exactly(1).times
        subject.sync(approved_translations_only: false)
      end
    end

    context "with errors on cleaning up transaltions" do
      it "doesn't affect execution" do
        expect(adapter).to receive(:approved_translations).with('fr', batch_size).and_yield(translations_response)
        expect(model).to receive(:update).with('1', translation1['1'])
        expect(model).to receive(:update).with('3', translation2['3'])
        expect(another_model).to receive(:update).with('4', translations['AnotherModel']['4'])
        expect(adapter).to receive(:cleanup_translations).and_return(CrowdIn::Adapter::ReturnObject.new(nil, error))
        expect(logger).to receive(:info).exactly(5).times
        expect(logger).to receive(:error).with("[Class] #{error}").exactly(1).times
        subject.sync(approved_translations_only: true)
      end
    end
  end

  context "#process_translation_result_with_duplicates" do
    let(:translations) {
      {
        "source_text" => {
          "Model" => {
            "1" => { "field1" => "source1" },
            "2" => { "field2" => "source2" }
          }
        },
        "translation" => {
          "Model" => {
            "1" => { "field1" => "translation1" },
            "2" => { "field2" => "translation2" }
          }
        }
      }
    }
    let(:translations_response) { CrowdIn::Adapter::ReturnObject.new(translations, nil) }

    before do
      I18n.available_locales = [:en, :fr]
      I18n.default_locale = :en
    end

    it "fetches all duplicates to sync" do
      expect(model).to receive(:where).with("field1 = ?", "source1").and_return([{ id: 1 }, { id: 3 }])
      expect(model).to receive(:where).with("field2 = ?", "source2").and_return([{ id: 2 }])
      expect(model).to receive(:update).with(1, { "field1" => "translation1"} )
      expect(model).to receive(:update).with(3, { "field1" => "translation1"} )
      expect(model).to receive(:update).with(2, { "field2" => "translation2"} )
      expect(logger).to receive(:info).exactly(3).times
      subject.process_translation_result_with_duplicates(translations_response, :fr, {})
    end
  end
end
