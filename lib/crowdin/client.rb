require 'rest-client'

module CrowdIn
  class Client
    # Initialize a Rest Client to CrowdIn, with an api_key and project_id.
    # Configure it to always return responses in JSON format.
    def initialize(api_key:, project_id:, base_url: 'https://api.crowdin.com')
      @api_key = api_key
      @project_id = project_id
      @base_url = base_url

      options = {
          :headers                => {},
          :params                 => {},
          :timeout                => nil,
          :key                    => @api_key,
          :json                   => true
      }

      options[:headers] = {
          'Accept'                => 'application/json',
          'X-Ruby-Version'        => RUBY_VERSION,
          'X-Ruby-Platform'       => RUBY_PLATFORM
      }.merge(options[:headers])

      options[:params] = {
          :key                    => api_key,
          :json                   => true
      }.merge(options[:params])

      RestClient.proxy = ENV['http_proxy'] if ENV['http_proxy']
      @connection = RestClient::Resource.new(@base_url, options)
    end

    # Given a language, get the status of all the files uploaded
    # for translation.
    def language_status(language)
      params = { language: language }
      path = "/api/project/#{@project_id}/language-status"
      post_request(path, params)
    end

    # Given a file-path as it exists in CrowdIn, and a language,
    # export the contents of the translated files.
    #
    # NOTE, because this client is set up to only deal with JSON
    # responses, this function will only succeed for JSON
    # translation files.
    def export_file(file, language)
      params = { file: file, language: language }
      path = "/api/project/#{@project_id}/export-file"
      get_request(path, params)
    end

    # Given a file-path as it exists in CrowdIn, delete that file
    # from CrowdIn.
    def delete_file(file)
      path = "/api/project/#{@project_id}/delete-file"
      params = { file: file }
      post_request(path, params)
    end

    private

    def get_request(path, params)
      query = @connection.options[:params].merge(params)
      @connection[path].get(params: query) do |response, _, _|
        process_response(response)
      end
    end

    def post_request(path, params)
      query = @connection.options.merge(params)
      @connection[path].post(query) do |response, _, _|
        process_response(response)
      end
    end

    # Assumes that the response is in JSON format
    def process_response(response)
      body = JSON.load(response.body)

      if body.is_a?(Hash) && body['success'] == false
        code = body['error']['code']
        message = body['error']['message']
        error   = CrowdIn::Client::Errors::Error.new(code, message)
        raise(error)
      end

      body
    end
  end
end