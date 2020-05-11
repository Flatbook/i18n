require 'spec_helper'

RSpec.describe CrowdIn::Client do
  let(:api_key) { "key" }
  let(:project_id) { "project" }
  let(:language) { "fr" }
  let(:base_path) { "https://sonder.crowdin.com/api/v2/projects/#{project_id}" }
  subject { described_class.new(api_key: api_key, project_id: "project")}

  context "#files" do
    let(:response_string) { '{ "data": [ { "data": { "id": "123" } }, { "data": { "id": "234" } } ] }' }
    let(:response) { [ { "id" => "123" }, { "id" => "234" } ] }
    let(:limit) { 500 }
    let(:offset) { 0 }

    before do
      stub_request(:get, "#{base_path}/files?limit=#{limit}&offset=#{offset}")
          .to_return(body: response_string, status: 200)
    end

    it "returns files in a flattened list" do
      expect(subject.files).to eq response
    end

    context "with pagination" do
      let(:response) { Array.new(520, { "id" => "1" }) }
      let(:response_string) { { "data" => response[0..499].map { |e| { "data" => e } } }.to_json }
      let(:second_response_string) { { "data" => response[500..519].map { |e| { "data" => e } } }.to_json }

      before do
        # stub second pagination request
        stub_request(:get, "#{base_path}/files?limit=#{limit}&offset=500")
            .to_return(body: second_response_string, status: 200)
      end

      it "returns files after multiple calls in a flattened list" do
        expect(subject.files).to eq response
      end
    end
  end

  context "#file_status" do
    let(:file_id) { "123" }
    let(:response_string) { '{ "data": [ { "data": { "languageId": "fr" } }, { "data": { "languageId": "es" } } ] }' }

    before do
      stub_request(:get, "#{base_path}/files/#{file_id}/languages/progress")
          .to_return(body: response_string, status: 200)
    end

    it "returns all language status when no language param specified" do
      expect(subject.file_status(file_id)).to eq [ { "languageId" => "fr" }, { "languageId" => "es" } ]
    end

    it "returns expected response if expected language exists" do
      expect(subject.file_status(file_id, language)).to eq( { "languageId" => "fr" } )
    end

    it "returns expected response if expected language doesn't exists" do
      expect(subject.file_status(file_id, "blah")).to eq nil
    end
  end

  context "#language_status" do
    let(:file1_id) { "123" }
    let(:file2_id) { "234" }
    let(:files_response_string) { "{ \"data\": [ { \"data\": { \"id\": \"#{file1_id}\" } }, { \"data\": { \"id\": \"#{file2_id}\" } } ] }" }
    let(:files_response) { [ { "id" => file1_id }, { "id" => file2_id } ] }
    let(:limit) { 500 }
    let(:offset) { 0 }
    let(:status_response_string) { '{ "data": [ { "data": { "languageId": "fr" } } ] }' }

    before do
      stub_request(:get, "#{base_path}/files?limit=#{limit}&offset=#{offset}")
          .to_return(body: files_response_string, status: 200)
      stub_request(:get, "#{base_path}/files/#{file1_id}/languages/progress")
          .to_return(body: status_response_string, status: 200)
      stub_request(:get, "#{base_path}/files/#{file2_id}/languages/progress")
          .to_return(body: status_response_string, status: 200)
    end

    it "returns expected response" do
      expected_response = [ { "file_id" => file1_id, "languageId" => "fr" }, { "file_id" => file2_id, "languageId" => "fr" } ]
      expect(subject.language_status(language)).to eq expected_response
    end
  end

  context "#export_file" do
    let(:follow_url) { "https://follow-url.com" }
    let(:build_response_string) { "{ \"data\": { \"url\": \"#{follow_url}\" } }" }
    let(:export_response_string) { '{ "key1": "val1", "key2": "val2" }' }
    let(:file_id) { "123" }

    before do
      stub_request(:post, "#{base_path}/translations/builds/files/#{file_id}")
          .with(body: hash_including( { targetLanguageId: language } ))
          .to_return(body: build_response_string, status: 200)
      stub_request(:get, follow_url)
          .to_return(body: export_response_string, status: 200)
    end

    it "returns expected response" do
      expected_response = JSON.load(export_response_string)
      expect(subject.export_file(file_id, language)).to eq expected_response
    end

    it "raises error when no url given by build response" do
      stub_request(:post, "#{base_path}/translations/builds/files/#{file_id}")
          .with(body: hash_including( { targetLanguageId: language } ))
          .to_return(body: '{ "data": {} }', status: 200)
      msg = "-1: No URL given to follow to export file"
      expect { subject.export_file(file_id, language) }.to raise_error(CrowdIn::Client::Errors::Error, msg)
    end

    it "raises error when url to follow errors out" do
      msg = '{ "error": { "code": 500, "message": "error message" } }'
      stub_request(:get, follow_url)
          .to_return(body: msg, status: 500)
      expect { subject.export_file(file_id, language) }.to raise_error(CrowdIn::Client::Errors::Error, "500: #{msg}")
    end
  end

  context "#delete_file" do
    let(:file_id) { "123" }

    context "on success" do
      before do
        stub_request(:delete, "#{base_path}/files/#{file_id}")
            .to_return(status: 204)
      end

      it "returns expected response" do
        expect(subject.delete_file(file_id)).to eq nil
      end
    end

    context "on failure" do
      let(:response_string) { '{ "error": { "code": 404, "message": "error message" } }' }

      before do
        stub_request(:delete, "#{base_path}/files/#{file_id}")
            .to_return(body: response_string, status: 404)
      end

      it "returns expected response" do
        expect { subject.delete_file(file_id) }.to raise_error(CrowdIn::Client::Errors::Error, "404: error message")
      end
    end
  end
end

