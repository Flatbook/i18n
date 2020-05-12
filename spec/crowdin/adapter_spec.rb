require 'spec_helper'

RSpec.describe CrowdIn::Adapter do
  let(:language) { "fr" }
  let(:client) { instance_double(CrowdIn::Client) }
  subject { described_class.new(client)}
  let(:error) { CrowdIn::Client::Errors::Error.new(404, "not found") }

  let(:file1_id) { '1' }
  let(:file2_id) { '2' }
  let(:file3_id) { '3' }
  let(:status) {
    [
        { "file_id" => file1_id, "approvalProgress" => 100 },
        { "file_id" => file2_id, "approvalProgress" => 75 },
        { "file_id" => file3_id, "approvalProgress" => 100 },
    ]
  }
  let(:raw_translations_1) {
    { "Model" => { "1" => {
        "1000" => { "field1" => "val 3" },
        "555" => { "field1" => "val 1", "field2" => "val 2" }
    } } }
  }
  let(:raw_translations_2) {
    { "AnotherModel" => { "1" => {
        "1000" => { "field1" => "val 3" },
        "555" => { "field1" => "val 1", "field2" => "val 2" }
    } } }
  }
  let(:expected_output) {
    {
        "Model" => { "1" => { "field1" => "val 3", "field2" => "val 2" } },
        "AnotherModel" => { "1" => { "field1" => "val 3", "field2" => "val 2" } }
    }
  }

  context "#translations" do
    it "returns translations for only completely approved files" do
      expect(client).to receive(:language_status).with(language).and_return(status)
      expect(client).to receive(:export_file).with(file1_id, language).and_return(raw_translations_1)
      expect(client).to receive(:export_file).with(file3_id, language).and_return(raw_translations_2)

      r = subject.translations(language)
      expect(r.success).to eq expected_output
      expect(r.failure).to be_nil
    end

    it "returns failed files when some approved files fail export" do
      expect(client).to receive(:language_status).with(language).and_return(status)
      expect(client).to receive(:export_file).with(file1_id, language).and_raise(error)
      expect(client).to receive(:export_file).with(file3_id, language).and_return(raw_translations_2)

      r = subject.translations(language)
      expect(r.success).to eq(expected_output.except("Model"))
      expect(r.failure).to eq(CrowdIn::FileMethods::FilesError.new({file1_id => error.to_s }) )

    end

    it "returns overall failure if we fail to fetch language status" do
      expect(client).to receive(:language_status).with(language).and_raise(error)
      r = subject.translations(language)
      expect(r.success).to eq({})
      expect(r.failure).to eq error
    end
  end

  context "#translation_for_file" do
    let(:expected_output) {
      { "Model" => { "1" => { "field1" => "val 3", "field2" => "val 2" } } }
    }

    it "returns translations for given file" do
      expect(client).to receive(:export_file).with(file1_id, language).and_return(raw_translations_1)

      r = subject.translations_for_file(file1_id, language)
      expect(r.success).to eq expected_output
      expect(r.failure).to be_nil
    end

    it "returns failure if export_file raises an error" do
      expect(client).to receive(:export_file).with(file1_id, language).and_raise(error)

      r = subject.translations_for_file(file1_id, language)
      expect(r.success).to be_empty
      expect(r.failure).to eq(CrowdIn::FileMethods::FilesError.new({file1_id => error.to_s }))
    end
  end

  context "#cleanup_translations" do
    it "deletes files that have been approved" do
      allow(client).to receive(:language_status).with(language).and_return(status)
      allow(client).to receive(:export_file).with(file1_id, language).and_return({})
      allow(client).to receive(:export_file).with(file3_id, language).and_return({})
      expect(client).to receive(:delete_file).with(file1_id)
      expect(client).to receive(:delete_file).with(file3_id)

      subject.translations(language)
      r = subject.cleanup_translations
      expect(r.success).to be_nil
      expect(r.failure).to be_nil
    end

    it "does nothing if no files have been approved" do
      r = subject.cleanup_translations
      expect(r.success).to be_nil
      expect(r.failure).to be_nil
    end

    it "returns failed file to delete if one failed deletion" do
      allow(client).to receive(:language_status).with(language).and_return(status)
      allow(client).to receive(:export_file).with(file1_id, language).and_return({})
      allow(client).to receive(:export_file).with(file3_id, language).and_return({})
      expect(client).to receive(:delete_file).with(file1_id)
      expect(client).to receive(:delete_file).with(file3_id).and_raise(error)

      subject.translations(language)
      r = subject.cleanup_translations
      expect(r.success).to be_nil
      expect(r.failure).to eq(CrowdIn::FileMethods::FilesError.new({file3_id => error.to_s }))
    end

    it "doesn't clean up approved file that failed export" do
      allow(client).to receive(:language_status).with(language).and_return(status)
      allow(client).to receive(:export_file).with(file1_id, language).and_raise(error)
      allow(client).to receive(:export_file).with(file3_id, language).and_return({})
      expect(client).to receive(:delete_file).with(file3_id)
      expect(client).not_to receive(:delete_file).with(file1_id)

      subject.translations(language)
      r = subject.cleanup_translations
      expect(r.success).to be_nil
      expect(r.failure).to be_nil
    end
  end

  context "#cleanup_file" do
    it "deletes file with passed in file_id" do
      expect(client).to receive(:delete_file).with(file1_id)
      r = subject.cleanup_file(file1_id)
      expect(r.success).to be_nil
      expect(r.failure).to be_nil
    end

    it "returns failed file with message on error" do
      expect(client).to receive(:delete_file).with(file1_id).and_raise(error)
      r = subject.cleanup_file(file1_id)
      expect(r.success).to be_nil
      expect(r.failure).to eq(CrowdIn::FileMethods::FilesError.new({file1_id => error.to_s }))
    end
  end
end

