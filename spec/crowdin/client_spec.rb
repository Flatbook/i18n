require 'spec_helper'
require 'crowdin/client/error'

RSpec.describe CrowdIn::Client do
  let(:api_key) { "key" }
  let(:project_id) { "project" }
  let(:language) { "fr" }
  subject { described_class.new(api_key: api_key, project_id: "project")}

  context "#language_status" do
    let(:response_string) { '{ "files": [] }' }
    let(:response) { JSON.load(response_string) }

    before do
      stub_request(:post, "https://api.crowdin.com/api/project/#{project_id}/language-status")
          .with(body: hash_including( { language: language } ))
          .to_return(body: response_string, status: 200)
    end

    it "returns expected response" do
      expect(subject.language_status(language)).to eq response
    end
  end

  context "#export_file" do
    let(:response_string) { '{ "key1": "val1" }' }
    let(:response) { JSON.load(response_string) }
    let(:file_path) { "some/file/path" }

    before do
      stub_request(:get, "https://api.crowdin.com/api/project/#{project_id}/export-file")
          .with(query: hash_including( { language: language, file: file_path } ))
          .to_return(body: response_string, status: 200)
    end

    it "returns expected response" do
      expect(subject.export_file(file_path, language)).to eq response
    end
  end

  context "#delete_file" do
    let(:response_string) { '{ "files": [] }' }
    let(:response) { JSON.load(response_string) }
    let(:file_path) { "some/file/path" }

    before do
      stub_request(:post, "https://api.crowdin.com/api/project/#{project_id}/delete-file")
          .with(body: hash_including( { file: file_path } ))
          .to_return(body: response_string, status: 200)
    end

    it "returns expected response" do
      expect(subject.delete_file(file_path)).to eq response
    end
  end

  context "for an error response" do
    let(:response_string) { '{ "success": false, "error": { "code": 1, "message": "error message" } }' }
    let(:file_path) { "some/file/path" }

    before do
      stub_request(:post, "https://api.crowdin.com/api/project/#{project_id}/delete-file")
          .to_return(body: response_string, status: 404)
    end

    it "raises an error" do
      expect { subject.delete_file(file_path) }.to raise_error(CrowdIn::Client::Errors::Error, "1: error message")
    end
  end
end

