require 'spec_helper'

RSpec.describe I18nSonder::DeleteStrings do
  let(:client) { instance_double(CrowdIn::Client) }
  let(:adapter) { CrowdIn::Adapter.new(client) }
  let(:id) { 1 }
  let(:instance) { Post.new(id: id, title: 'T1', content: 'some content', published: true) }
  let(:not_found_error) { CrowdIn::Client::Errors::Error.new(404, "not found") }
  let(:file_error) { CrowdIn::FileMethods::FilesError.new(not_found_error) }

  subject(:delete) { described_class.new(instance).delete }

  describe "#delete" do
    before do
      # allow_any_instance_of(CrowdIn::Adapter)
      #   .to receive(:new)
      #   .and_return(adapter)
      # allow_any_instance_of(CrowdIn::Client)
      #   .to receive(:new)
      #   .and_return(client)
      allow(I18nSonder).to receive(:localization_provider).and_return(adapter)
      AdapterResult = Struct.new(:success, :failure)
    end

    it "deletes files for specified model" do
      expect(adapter).to receive(:delete_source_files_for_model).with(instance).and_return(AdapterResult.new(nil, nil))

      result = delete

      expect(result).to be_nil
    end

    it "returns failed file to delete if one failed deletion" do
      expect(adapter).to receive(:delete_source_files_for_model).with(instance).and_return(AdapterResult.new(nil, file_error))

      result = delete

      expect(result).to eq(CrowdIn::FileMethods::FilesError.new({ "1" => not_found_error.to_s }))
    end
  end
end
