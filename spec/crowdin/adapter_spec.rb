require 'spec_helper'

RSpec.describe CrowdIn::Adapter do
  let(:language) { "fr" }
  let(:client) { instance_double(CrowdIn::Client) }
  subject { described_class.new(client)}
  let(:error) { CrowdIn::Client::Errors::Error.new(404, "not found") }

  let(:file1_id) { '1' }
  let(:file2_id) { '2' }
  let(:file3_id) { '3' }
  let(:file4_id) { '4' }
  let(:status) {
    [
        { "file_id" => file1_id, "approvalProgress" => 100 },
        { "file_id" => file2_id, "approvalProgress" => 75 },
        { "file_id" => file3_id, "approvalProgress" => 100 },
        { "file_id" => file4_id, "approvalProgress" => 100 },
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
  let(:raw_translations_3) {
    { "ModelWithoutUpdated" => { "1" => { "field1" => "val 1", "field2" => "val 2" } } }
  }
  let(:expected_output) {
    {
        "Model" => { "1" => { "field1" => "val 3", "field2" => "val 2" } },
        "AnotherModel" => { "1" => { "field1" => "val 3", "field2" => "val 2" } },
        "ModelWithoutUpdated" => { "1" => { "field1" => "val 1", "field2" => "val 2" } }
    }
  }

  context "#translations" do
    it "returns translations for only completely approved files" do
      expect(client).to receive(:language_status).with(language).and_return(status)
      expect(client).to receive(:export_file).with(file1_id, language).and_return(raw_translations_1)
      expect(client).to receive(:export_file).with(file2_id, language).and_return(raw_translations_2)
      expect(client).to receive(:export_file).with(file3_id, language).and_return(raw_translations_2)
      expect(client).to receive(:export_file).with(file4_id, language).and_return(raw_translations_3)

      r = subject.translations(language)
      expect(r.success).to eq expected_output
      expect(r.failure).to be_nil
    end

    it "returns failed files when some approved files fail export" do
      expect(client).to receive(:language_status).with(language).and_return(status)
      expect(client).to receive(:export_file).with(file1_id, language).and_raise(error)
      expect(client).to receive(:export_file).with(file2_id, language).and_return(raw_translations_2)
      expect(client).to receive(:export_file).with(file3_id, language).and_return(raw_translations_2)
      expect(client).to receive(:export_file).with(file4_id, language).and_return(raw_translations_3)

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

  context "#approved_translations" do
    it "returns translations for only completely approved files" do
      expect(client).to receive(:language_status).with(language).and_return(status)
      expect(client).to receive(:export_file).with(file1_id, language).and_return(raw_translations_1)
      expect(client).to receive(:export_file).with(file3_id, language).and_return(raw_translations_2)
      expect(client).to receive(:export_file).with(file4_id, language).and_return(raw_translations_3)

      r = subject.approved_translations(language)
      expect(r.success).to eq expected_output
      expect(r.failure).to be_nil
    end

    it "returns failed files when some approved files fail export" do
      expect(client).to receive(:language_status).with(language).and_return(status)
      expect(client).to receive(:export_file).with(file1_id, language).and_raise(error)
      expect(client).to receive(:export_file).with(file3_id, language).and_return(raw_translations_2)
      expect(client).to receive(:export_file).with(file4_id, language).and_return(raw_translations_3)

      r = subject.approved_translations(language)
      expect(r.success).to eq(expected_output.except("Model"))
      expect(r.failure).to eq(CrowdIn::FileMethods::FilesError.new({file1_id => error.to_s }) )
    end

    it "returns overall failure if we fail to fetch language status" do
      expect(client).to receive(:language_status).with(language).and_raise(error)
      r = subject.approved_translations(language)
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

    it "returns translations for given file when object doesn't have updated_at" do
      expect(client).to receive(:export_file).with(file1_id, language).and_return(raw_translations_3)

      r = subject.translations_for_file(file1_id, language)
      expect(r.success).to eq({ "ModelWithoutUpdated" => { "1" => { "field1" => "val 1", "field2" => "val 2" } } })
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
    let(:syncd) { { "Model" => { "1" => [:fr], "2" => [:es, :fr], "3" => [:es, :fr] } } }

    it "only deletes files for objects where all language translations have been sync'd" do
      expect(client).to receive(:find_file_by_name).with("Model-2").and_return(file2_id)
      expect(client).to receive(:find_file_by_name).with("Model-3").and_return(file3_id)
      expect(client).to receive(:delete_file).with(file2_id)
      expect(client).to receive(:delete_file).with(file3_id)

      r = subject.cleanup_translations(syncd, [:es, :fr])
      expect(r.success).to be_nil
      expect(r.failure).to be_nil
    end

    it "returns failed file to delete if one failed deletion" do
      expect(client).to receive(:find_file_by_name).with("Model-2").and_return(file2_id)
      expect(client).to receive(:find_file_by_name).with("Model-3").and_return(file3_id)
      expect(client).to receive(:delete_file).with(file2_id)
      expect(client).to receive(:delete_file).with(file3_id).and_raise(error)

      r = subject.cleanup_translations(syncd, [:es, :fr])
      expect(r.success).to be_nil
      expect(r.failure).to eq(CrowdIn::FileMethods::FilesError.new({file3_id => error.to_s }))
    end

    it "does nothing if the input argument is empty" do
      expect(client).not_to receive(:find_file_by_name)
      expect(client).not_to receive(:delete_file)

      r = subject.cleanup_translations({}, [:es, :fr])
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

  context "#upload_attributes_to_translate" do
    let(:object_type) { "Foo::Bar" }
    let(:object_id) { "1" }
    let(:updated_at) { "1234" }
    let(:attributes) { { "field1" => "val 1. val 2.", "field2" => "val 3. val 4." } }
    let(:content) { { object_type => { object_id => { updated_at => {
        "field1" => "val 1. val 2.",
        "field2" => [ "val 3.", "val 4." ]
    } } } }.to_json }
    let(:params) { { "field2" => { split_into_sentences: true } } }
    let(:options) { { translated_attribute_params: params } }
    let(:file_name) { "Foo_Bar-1.json" }
    let(:file_base_name) { "Foo_Bar-1"}

    context "for a new object" do
      it "adds a new file with content split by sentences according to params" do
        expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
        expect(client).to receive(:add_file).with(file_name, content).and_return(nil)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to be_nil
      end

      it "returns failures when adding file errors" do
        expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
        expect(client).to receive(:add_file).with(file_name, content).and_raise(error)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to eq error
      end
    end

    context "for an object with existing CrowdIn file" do
      before do
        expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(file1_id)
      end

      it "updates existing CrowdIn file with expected content if current updated_at is greater than what exists" do
        existing_content = { object_type => { object_id => { "1000" => {} } } }
        expect(client).to receive(:download_source_file).with(file1_id).and_return(existing_content)
        expect(client).to receive(:update_file).with(file1_id, content).and_return(nil)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to be_nil
      end

      it "does not update if current updated_at is same as what exists" do
        existing_content = { object_type => { object_id => { updated_at => {} } } }
        expect(client).to receive(:download_source_file).with(file1_id).and_return(existing_content)
        expect(client).not_to receive(:update_file)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to be_nil
      end

      it "does not update if current updated_at is earlier than as what exists" do
        existing_content = { object_type => { object_id => { "2000" => {} } } }
        expect(client).to receive(:download_source_file).with(file1_id).and_return(existing_content)
        expect(client).not_to receive(:update_file)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to be_nil
      end

      it "does not update if object not found in source file" do
        existing_content = { object_type => { "other_object_id" => { "1000" => {} } } }
        expect(client).to receive(:download_source_file).with(file1_id).and_return(existing_content)
        expect(client).not_to receive(:update_file)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expected_error = CrowdIn::FileMethods::FilesError.new({ file1_id => "Could not find #{object_type} #{object_id}" })
        expect(r.failure).to eq expected_error
      end

      it "returns failures when downloading file errors" do
        expect(client).to receive(:download_source_file).with(file1_id).and_raise(error)
        expect(client).not_to receive(:update_file)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to eq error
      end

      it "returns failures when updating file errors" do
        existing_content = { object_type => { object_id => { "1000" => {} } } }
        expect(client).to receive(:download_source_file).with(file1_id).and_return(existing_content)
        expect(client).to receive(:update_file).with(file1_id, content).and_raise(error)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to eq error
      end
    end

    context "for an object without the updated_at column" do
      let(:content) { { object_type => { object_id => {
          "field1" => "val 1. val 2.",
          "field2" => [ "val 3.", "val 4." ]
      } } }.to_json }

      it "adds a new file with content split by sentences according to params" do
        expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
        expect(client).to receive(:add_file).with(file_name, content).and_return(nil)

        r = subject.upload_attributes_to_translate(object_type, object_id, nil, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to be_nil
      end
    end

    it "returns failures when finding file by name errors" do
      expect(client).to receive(:find_file_by_name).with(file_base_name).and_raise(error)
      expect(client).not_to receive(:add_file)
      expect(client).not_to receive(:update_file)

      r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
      expect(r.success).to be_nil
      expect(r.failure).to eq error
    end

    context "with a namespace" do
      let(:namespace) { "namespace" }
      let(:directory) { 123 }
      let(:options) { { translated_attribute_params: params, namespace: [namespace] } }

      it "adds a new file under that namespace when namespace already exists" do
        expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
        expect(client).to receive(:find_directory_by_name).with(namespace).and_return(directory)
        expect(client).not_to receive(:add_directory)
        expect(client).to receive(:add_file).with(file_name, content, directory).and_return(nil)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to be_nil
      end

      it "adds a new file under that namespace when namespace doesn't exists" do
        expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
        expect(client).to receive(:find_directory_by_name).with(namespace).and_return(false)
        expect(client).to receive(:add_directory).with(namespace).and_return(directory)
        expect(client).to receive(:add_file).with(file_name, content, directory).and_return(nil)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to be_nil
      end

      it "returns failures when adding file errors" do
        expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
        expect(client).to receive(:find_directory_by_name).with(namespace).and_raise(error)

        r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
        expect(r.success).to be_nil
        expect(r.failure).to eq error
      end

      context "that is empty" do
        let(:options) { { translated_attribute_params: params, namespace: [] } }

        it "adds a new file without namespace" do
          expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
          expect(client).not_to receive(:find_directory_by_name)
          expect(client).not_to receive(:add_directory)
          expect(client).to receive(:add_file).with(file_name, content).and_return(nil)

          r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
          expect(r.success).to be_nil
          expect(r.failure).to be_nil
        end
      end

      context "that is nil" do
        let(:options) { { translated_attribute_params: params, namespace: nil } }

        it "adds a new file without namespace" do
          expect(client).to receive(:find_file_by_name).with(file_base_name).and_return(false)
          expect(client).not_to receive(:find_directory_by_name)
          expect(client).not_to receive(:add_directory)
          expect(client).to receive(:add_file).with(file_name, content).and_return(nil)

          r = subject.upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
          expect(r.success).to be_nil
          expect(r.failure).to be_nil
        end
      end
    end
  end
end
