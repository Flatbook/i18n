require 'rest-client'
require 'crowdin/client/error'

module CrowdIn
  class Client
    # Initialize a Rest Client to CrowdIn, with an api_key and project_id.
    # Configure it to always return responses in JSON format.
    def initialize(api_key:, project_id:, base_url: 'https://sonder.crowdin.com')
      @project_id = project_id

      options = {
          headers: {},
          params: {},
          timeout: nil,
      }

      options[:headers] = {
          'Content-Type': 'application/json',
          'Authorization': "Bearer #{api_key}"
      }.merge(options[:headers])

      RestClient.proxy = ENV['http_proxy'] if ENV['http_proxy']
      @connection = RestClient::Resource.new(base_url, options)

      @files_cache = {}
      @files_status_cache = {}
    end

    # Get metadata for all files in a project
    def files(hard_fetch = false)
      if @files_cache.empty? || hard_fetch
        path = "api/v2/projects/#{@project_id}/files"
        @files_cache = with_pagination { |params| get_request(path, params) }
      end
      @files_cache
    end

    # Get the translation progress for a given file.
    # If no language provided, then statuses for each languages: Array[translation_progress].
    # If specified language isn't found, returns nil.
    def file_status(file_id, language = nil, hard_fetch = false)
      if !@files_status_cache.key?(file_id) || hard_fetch
        path = "api/v2/projects/#{@project_id}/files/#{file_id}/languages/progress"
        @files_status_cache[file_id] = get_request(path)
      end

      if language.nil?
        @files_status_cache[file_id]
      else
        @files_status_cache[file_id].find { |s| s['languageId'] == language }
      end
    end

    # Given a language, get the status of all the files uploaded
    # for translation.
    def language_status(language)
      files.map do |f|
        file_id = f['id']
        file_status(file_id, language)&.merge('file_id' => file_id)
      end.compact
    end

    # Given a CrowdIn file_id, and a language, export the contents of the translated files.
    #
    # NOTE, because this client is set up to only deal with JSON
    # responses, this function will only succeed for JSON
    # translation files.
    def export_file(file_id, language)
      # This path returns a URL to follow to download the translated content
      path = "api/v2/projects/#{@project_id}/translations/builds/files/#{file_id}"
      body = { targetLanguageId: language }.to_json
      result = post_request(path, body, content_type: :json)

      # Follow the content URL
      follow_url(result)
    end

    # Given a CrowdIn file_id, delete that file from CrowdIn.
    def delete_file(file_id)
      path = "api/v2/projects/#{@project_id}/files/#{file_id}"
      delete_request(path)
    end

    # Find the first file in CrowdIn whose basename is equal to the given name.
    # The +name+ argument must be the basename of the file, e.g. "File_123.json"'s
    # basename is "File_123".
    #
    # Return the files's id, if found, else return false.
    def find_file_by_name(name)
      file = files.find { |f| name == File.basename(f['name'], ".*") }
      file.present? ? file['id'] : false
    end

    # Add a new file given file name and content.
    # This first creates a storage object in CrowdIn, and then applies that
    # storage to a new file.
    def add_file(name, content)
      storage = add_storage(name, content)

      path = "api/v2/projects/#{@project_id}/files"
      body = { storageId: storage['id'], name: storage['fileName'] }.to_json
      post_request(path, body, content_type: :json)
    end

    def add_storage(name, content)
      path = "api/v2/storages"
      body = content
      headers = { :"Crowdin-API-FileName" => name, content_type: :json }
      post_request(path, body, headers)
    end

    # Given a CrowdIn, retrieve the contents of that file.
    # Assumes that files being retrieved are in JSON format.
    def download_source_file(file_id)
      path = "api/v2/projects/#{@project_id}/files/#{file_id}/download"
      result = get_request(path, {})
      follow_url(result)
    end

    # Add a new file given CrowdIn file id and content to update.
    # This first creates a storage object in CrowdIn, and then applies that
    # storage to an existing file. We keep the existing translations and approvals.
    def update_file(file_id, content)
      storage_name = "update_for_#{file_id}.json"
      storage = add_storage(storage_name, content)

      path = "api/v2/projects/#{@project_id}/files/#{file_id}"
      body = { storageId: storage['id'], updateOption: "keep_translations_and_approvals" }.to_json
      put_request(path, body, content_type: :json)
    end

    private

    def get_request(path, params = {})
      query = @connection.options[:params].merge(params)
      @connection[path].get(params: query) do |response, _, _|
        process_response(response)
      end
    end

    def post_request(path, params, headers)
      @connection[path].post(params, headers) do |response, _, _|
        process_response(response)
      end
    end

    def delete_request(path)
      @connection[path].delete do |response, _, _|
        if response.code < 200 || response.code >= 300
          process_response(response)
        end
      end
    end

    def put_request(path, params, headers)
      @connection[path].put(params, headers) do |response, _, _|
        process_response(response)
      end
    end

    def with_pagination
      pagination_limit = 500
      offset = 0
      final_result = []
      loop do
        params = { limit: pagination_limit, offset: offset }
        page_result = yield params
        final_result += page_result
        break if page_result.size < pagination_limit
        offset += pagination_limit
      end
      final_result
    end

    # Assumes that the response is in JSON format
    def process_response(response)
      begin
        body = JSON.load(response.body)
      rescue
        raise CrowdIn::Client::Errors::Error.new(
            -1, "Could not parse response into JSON: #{response.body}"
        )
      end

      if body.key? 'error'
        raise CrowdIn::Client::Errors::Error.new(
            body['error']['code'],
            body['error']['message']
        )
      elsif body.key? 'data'
        # response comes in nested format with a lot of "data" keys, which we can flatten
        flatten_data_nodes(body)
      else
        raise CrowdIn::Client::Errors::Error.new(-1 ,"Unexpected response format: #{response}")
      end
    end

    # Recursively remove the 'data' key in the response body
    def flatten_data_nodes(body)
      if body.is_a? Array
        body.map { |n| flatten_data_nodes(n) }
      elsif body.is_a? Hash
        body.key?('data') ? flatten_data_nodes(body['data']) : body
      else
        body
      end
    end

    def follow_url(result)
      unless result.is_a?(Hash) && result.key?('url')
        raise CrowdIn::Client::Errors::Error.new(-1, "No URL given to follow to export file")
      end

      RestClient::Request.execute(method: :get, url: result['url']) do |r, _, _|
        unless r.code == 200
          raise CrowdIn::Client::Errors::Error.new(r.code, r.body.to_s)
        end
        JSON.load(r.body)
      end
    end
  end
end