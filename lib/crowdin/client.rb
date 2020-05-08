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
    end

    # Get metadata for all files in a project
    def files
      path = "api/v2/projects/#{@project_id}/files"
      with_pagination { |params| get_request(path, params) }
    end

    # Get the translation progress for a given file.
    # If no language provided, then statuses for each languages: Array[translation_progress].
    # If specified language isn't found, returns nil.
    def file_status(file_id, language = nil)
      path = "api/v2/projects/#{@project_id}/files/#{file_id}/languages/progress"
      if language.nil?
        get_request(path)
      else
        get_request(path).find { |s| s['languageId'] == language }
      end
    end

    # Given a language, get the status of all the files uploaded
    # for translation.
    def language_status(language)
      file_ids = files.map { |f| f['id'] }
      file_ids.map { |f_id| file_status(f_id, language).merge('file_id' => f_id) }
    end

    # Given a CrowdIn file_id, and a language, export the contents of the translated files.
    #
    # NOTE, because this client is set up to only deal with JSON
    # responses, this function will only succeed for JSON
    # translation files.
    def export_file(file_id, language)
      # This path returns a URL to follow to download the translated content
      path = "api/v2/projects/#{@project_id}/translations/builds/files/#{file_id}"
      params = { targetLanguageId: language }
      result = post_request(path, params)

      # Follow the content URL
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

    # Given a CrowdIn file_id, delete that file from CrowdIn.
    def delete_file(file_id)
      path = "api/v2/projects/#{@project_id}/files/#{file_id}"
      delete_request(path)
    end

    private

    def get_request(path, params = {})
      query = @connection.options[:params].merge(params)
      @connection[path].get(params: query) do |response, _, _|
        process_response(response)
      end
    end

    def post_request(path, params)
      @connection[path].post(params.to_json, content_type: :json) do |response, _, _|
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
      body = JSON.load(response.body)

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
  end
end