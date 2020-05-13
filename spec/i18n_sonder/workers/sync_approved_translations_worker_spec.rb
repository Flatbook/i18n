require 'spec_helper'

RSpec.describe I18nSonder::Workers::SyncApprovedTranslationsWorker do
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
  let(:another_model) do
    stub_const 'AnotherModel', Class.new
    class_double(AnotherModel).as_stubbed_const(transfer_nested_constants: true)
  end
  let(:translation1) { { "1" => { "field1" => "val 3", "field2" => "val 2" } } }
  let(:translation2) { { "3" => { "field1" => "val 3", "field2" => "val 2" } } }
  let(:translation3) { { "4" => { "field3" => "val 3", "field4" => "val 2" } } }
  let(:translations) { { "Model" => translation1.merge(translation2), "AnotherModel" => translation3 } }

  let(:error) { CrowdIn::Client::Errors::Error.new(404, "not found") }

  context "#perform" do
    let(:translations_response) { CrowdIn::Adapter::ReturnObject.new(translations, nil) }
    let(:cleanup_response) { CrowdIn::Adapter::ReturnObject.new(nil, nil) }

    before do
      I18n.available_locales = [:en, :fr]
      I18n.default_locale = :en
    end

    it "fetches translations, writes them to the DB, and then cleans them up" do
      expect(adapter).to receive(:translations).with('fr').and_return(translations_response)
      expect(model).to receive(:update!).with('1', translation1['1'])
      expect(model).to receive(:update!).with('3', translation2['3'])
      expect(another_model).to receive(:update!).with('4', translations['AnotherModel']['4'])
      expect(adapter).to receive(:cleanup_translations).and_return(cleanup_response)
      expect(logger).to receive(:info).exactly(5).times
      expect(logger).not_to receive(:error)
      subject.perform
    end

    context "with errors on fetchhng transaltions" do
      let(:translations) { { "Model" => translation1 } }

      context "with no valid translations" do
        let(:translations_response) { CrowdIn::Adapter::ReturnObject.new({}, error) }

        it "does not write translations if adapter returns error with empty translations" do
          expect(adapter).to receive(:translations).with('fr').and_return(translations_response)
          expect(model).not_to receive(:update!)
          expect(adapter).to receive(:cleanup_translations).and_return(cleanup_response)
          expect(logger).to receive(:info).exactly(2).times
          expect(logger).to receive(:error).exactly(1).times
          subject.perform
        end
      end

      context "with valid translations" do
        let(:translations_response) { CrowdIn::Adapter::ReturnObject.new(translations, error) }

        it "writes valid translations and logs for error" do
          expect(adapter).to receive(:translations).with('fr').and_return(translations_response)
          expect(model).to receive(:update!).with('1', translation1['1'])
          expect(adapter).to receive(:cleanup_translations).and_return(cleanup_response)
          expect(logger).to receive(:info).exactly(3).times
          expect(logger).to receive(:error).exactly(1).times
          subject.perform
        end
      end
    end

    context "with errors on writing transaltions" do
      let(:error) { StandardError.new("error") }

      it "doesn't cleanup any translations and logs writing error" do
        expect(adapter).to receive(:translations).with('fr').and_return(translations_response)

        # Since the translations are in a hash, and only one translation throws an error,
        # we don't have a guarantee on the order with which we write translations.
        # So we allow all the updates, rather than expecting anything specifically.
        allow(model).to receive(:update!).with('1', translation1['1'])
        allow(model).to receive(:update!).with('3', translation2['3']).and_raise(error)
        allow(another_model).to receive(:update!).with('4', translations['AnotherModel']['4'])

        expect(adapter).not_to receive(:cleanup_translations)
        allow(logger).to receive(:info)
        expect(logger).to receive(:error).with(error).exactly(1).times
        subject.perform
      end
    end

    context "with errors on cleaning up transaltions" do
      it "doesn't affect execution" do
        expect(adapter).to receive(:translations).with('fr').and_return(translations_response)
        expect(model).to receive(:update!).with('1', translation1['1'])
        expect(model).to receive(:update!).with('3', translation2['3'])
        expect(another_model).to receive(:update!).with('4', translations['AnotherModel']['4'])
        expect(adapter).to receive(:cleanup_translations).and_raise(error)
        expect(logger).to receive(:info).exactly(5).times
        expect(logger).to receive(:error).with(error).exactly(1).times
        subject.perform
      end
    end
  end
end

