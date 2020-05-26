require 'spec_helper'

RSpec.describe CrowdIn::Client do
  let(:api_key) { "key" }
  let(:project_id) { "project" }
  let(:language) { "fr" }
  let(:base_path) { "https://sonder.crowdin.com/api/v2/projects/#{project_id}" }
  subject { described_class.new(api_key: api_key, project_id: project_id)}

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

    context "with caching" do
      let(:connection) { instance_double(RestClient::Resource) }

      before do
        subject.instance_variable_set(:@connection, connection)
      end

      it "uses cached results on subsequent calls" do
        expect(connection).to receive(:options).exactly(:once).and_return({ params: {} })
        expect(connection).to receive(:[]).exactly(:once).and_return(connection)
        expect(connection).to receive(:get).exactly(:once).and_return(response)
        # call #files twice and expect get request only once
        expect(subject.files).to eq response
        expect(subject.files).to eq response
      end

      it "fetches from CrowdIn if hard_fetch is requested" do
        expect(connection).to receive(:options).exactly(:twice).and_return({ params: {} })
        expect(connection).to receive(:[]).exactly(:twice).and_return(connection)
        expect(connection).to receive(:get).exactly(:twice).and_return(response)
        # call #files twice and expect get request twice with hard_fetch option
        expect(subject.files).to eq response
        expect(subject.files(hard_fetch = true)).to eq response
      end
    end
  end

  context "#file_status" do
    let(:file_id) { "123" }
    let(:response_string) { '{ "data": [ { "data": { "languageId": "fr" } }, { "data": { "languageId": "es" } } ] }' }
    let(:response) { [ { "languageId" => "fr" }, { "languageId" => "es" } ] }

    before do
      stub_request(:get, "#{base_path}/files/#{file_id}/languages/progress")
          .to_return(body: response_string, status: 200)
    end

    it "returns all language status when no language param specified" do
      expect(subject.file_status(file_id)).to eq response
    end

    it "returns expected response if expected language exists" do
      expect(subject.file_status(file_id, language)).to eq( { "languageId" => "fr" } )
    end

    it "returns expected response if expected language doesn't exists" do
      expect(subject.file_status(file_id, "blah")).to eq nil
    end

    context "with caching" do
      let(:connection) { instance_double(RestClient::Resource) }

      before do
        subject.instance_variable_set(:@connection, connection)
      end

      it "uses cached results on subsequent calls" do
        expect(connection).to receive(:options).exactly(:once).and_return({ params: {} })
        expect(connection).to receive(:[]).exactly(:once).and_return(connection)
        expect(connection).to receive(:get).exactly(:once).and_return(response)
        # call #files_status twice with different languages and expect get request only once
        expect(subject.file_status(file_id, "fr")).to eq( { "languageId" => "fr" } )
        expect(subject.file_status(file_id, "es")).to eq( { "languageId" => "es" } )
      end

      it "fetches from CrowdIn if hard_fetch is requested" do
        expect(connection).to receive(:options).exactly(:twice).and_return({ params: {} })
        expect(connection).to receive(:[]).exactly(:twice).and_return(connection)
        expect(connection).to receive(:get).exactly(:twice).and_return(response)
        # call #files_status twice and expect get request twice with hard_fetch option
        expect(subject.file_status(file_id, "fr")).to eq( { "languageId" => "fr" } )
        expect(subject.file_status(file_id, "fr", hard_fetch = true)).to eq( { "languageId" => "fr" } )
      end
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

    it "returns empty result for language that doesn't exist" do
      expect(subject.language_status("bad_lang")).to eq []
    end
  end

  context "methods that export content" do
    let(:follow_url) { "https://follow-url.com" }
    let(:build_response_string) { "{ \"data\": { \"url\": \"#{follow_url}\" } }" }
    let(:export_response_string) { '{ "key1": "val1", "key2": "val2" }' }
    let(:file_id) { "123" }

    before do
      stub_request(:get, follow_url)
          .to_return(body: export_response_string, status: 200)
    end

    context "#export_file" do
      before do
        stub_request(:post, "#{base_path}/translations/builds/files/#{file_id}")
            .with(body: hash_including( { targetLanguageId: language } ))
            .to_return(body: build_response_string, status: 200)
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

    context "#download_source_file" do
      before do
        stub_request(:get, "#{base_path}/files/#{file_id}/download")
            .to_return(body: build_response_string, status: 200)
      end

      it "returns expected response" do
        expected_response = JSON.load(export_response_string)
        expect(subject.download_source_file(file_id)).to eq expected_response
      end

      it "raises error when no url given by build response" do
        stub_request(:get, "#{base_path}/files/#{file_id}/download")
            .to_return(body: '{ "data": {} }', status: 200)
        msg = "-1: No URL given to follow to export file"
        expect { subject.download_source_file(file_id) }.to raise_error(CrowdIn::Client::Errors::Error, msg)
      end

      it "raises error when url to follow errors out" do
        msg = '{ "error": { "code": 500, "message": "error message" } }'
        stub_request(:get, follow_url)
            .to_return(body: msg, status: 500)
        expect { subject.download_source_file(file_id) }.to raise_error(CrowdIn::Client::Errors::Error, "500: #{msg}")
      end
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

  context "#file_file_by_name" do
    let(:file1_id) { "123" }
    let(:file1_name) { "file_123.json" }
    let(:file2_id) { "234" }
    let(:file2_name) { "file_234.json" }
    let(:files) { { data: [ { data: { id: file1_id, name: file1_name } }, { data: { id: file2_id, name: file2_name } } ] } }
    let(:files_response_string) { files.to_json }
    let(:limit) { 500 }
    let(:offset) { 0 }

    before do
      stub_request(:get, "#{base_path}/files?limit=#{limit}&offset=#{offset}")
          .to_return(body: files_response_string, status: 200)
    end

    it "returns file id when found" do
      expect(subject.find_file_by_name("file_123")).to eq file1_id
    end

    it "returns false when name is not found" do
      expect(subject.find_file_by_name("not_found")).to eq false
    end
  end

  context "mutating files" do
    let(:name) { "foo" }
    let(:content) { { "key1" => "value1" } }
    let(:storage_id) { 1 }
    let(:storage_response_status) { 201 }
    let(:file_response_status) { 200 }
    let(:response) { { "id" => storage_id, "fileName" => name} }
    let(:response_string) { "{ \"data\": #{response.to_json} }" }

    before do
      stub_request(:post, "https://sonder.crowdin.com/api/v2/storages")
          .with(
              headers: { "Crowdin-API-FileName" => name },
              body: content
          )
          .to_return(body: response_string, status: storage_response_status)
    end

    context "via #add_file" do
      before do
        stub_request(:post, "#{base_path}/files")
            .with(
                headers: { "Content-Type" => "application/json" },
                body: hash_including( { "storageId" => storage_id, "name" => name } )
            )
            .to_return(body: response_string, status: file_response_status)
      end

      context "on success" do
        it "returns expected response" do
          expect(subject.add_file(name, content)).to eq response
        end
      end

      context "on failure" do
        let(:response_string) { '{ "error": { "code": 404, "message": "error message" } }' }

        context "of adding storage" do
          let(:storage_response_status) { 404 }

          it "returns expected response" do
            expect { subject.add_file(name, content) }.to raise_error(CrowdIn::Client::Errors::Error, "404: error message")
          end
        end

        context "of adding file" do
          let(:file_response_status) { 404 }

          it "returns expected response" do
            expect { subject.add_file(name, content) }.to raise_error(CrowdIn::Client::Errors::Error, "404: error message")
          end
        end
      end
    end

    context "via #update_file" do
      let(:file_id) { "123" }
      let(:name) { "update_for_#{file_id}.json" }

      before do
        stub_request(:put, "#{base_path}/files/#{file_id}")
            .with(
                headers: { "Content-Type" => "application/json" },
                body: hash_including( { "storageId" => storage_id, "updateOption" => "keep_translations_and_approvals" } )
            )
            .to_return(body: response_string, status: file_response_status)
      end

      context "on success" do
        it "returns expected response" do
          expect(subject.update_file(file_id, content)).to eq response
        end
      end

      context "on failure" do
        let(:response_string) { '{ "error": { "code": 404, "message": "error message" } }' }

        context "of adding storage" do
          let(:storage_response_status) { 404 }

          it "returns expected response" do
            expect { subject.update_file(file_id, content) }.to raise_error(CrowdIn::Client::Errors::Error, "404: error message")
          end
        end

        context "of updating file" do
          let(:file_response_status) { 404 }

          it "returns expected response" do
            expect { subject.update_file(file_id, content) }.to raise_error(CrowdIn::Client::Errors::Error, "404: error message")
          end
        end
      end
    end
  end
end
