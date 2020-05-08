require 'crowdin/client'
require 'crowdin/file_methods'

module CrowdIn
  class Adapter
    include CrowdIn::FileMethods

    ReturnObject = Struct.new(:success, :failures)

    def initialize(api_key:, project_id:)
      @client = CrowdIn::Client.new(api_key: api_key, project_id: project_id)
    end

    # Given a language, fetch approved translations.
    # Returns Struct of approved translations hash, and hash of files we failed to fetch translations for.
    # Approved translations have the format:
    # {
    #   model: {
    #     id: {
    #       field_1: val1,
    #       field_2: val2
    #     }
    #   }
    # }
    #
    # Raises CrowdIn::Client::Errors::Error if we cannot obtain the translation status from CrowdIn.
    def translations!(language)
      status = @client.language_status(language)

      # Fetch list of approved translation file paths
      @approved_files = filter_approved_files(status['files'])

      # Coalesce files that correspond to the same object
      latest_approved_files = coalesce_files_for_same_object(@approved_files)

      # Fetch translations for each latest approved file
      translations = {}
      failed_files = safe_file_iteration(latest_approved_files) do |file_path|
        object_name, object_id = object_name_and_id(file_path)

        translations[object_name] = {} unless translations.key? object_name
        translations[object_name][object_id] = translations_for_file!(file_path, language)
      end

      ReturnObject.new(translations, failed_files)
    end

    # Delete all the approved translation files, stored in @approved_files.
    # This should be called after we successfully persist the approved translations.
    #
    # Returns failed files for those files that fail deletion.
    def cleanup_translations
      failed_files = safe_file_iteration(@approved_files) do |file|
        @client.delete_file(file)
      end

      ReturnObject.new(nil, failed_files)
    end

    private

    # Each file path has format the following format:
    # /models/[CLASS_NAME]/[CLASS_NAME]-[OBJECT_ID]-[OBJECT_UPDATED_AT_TIMESTAMP].json
    # and for models nested under modules:
    # /models/[MODULE_NAME]/[CLASS_NAME]/[CLASS_NAME]-[OBJECT_ID]-[OBJECT_UPDATED_AT_TIMESTAMP].json
    #
    # There could be multiple versions of the same object with different updated timestamps,
    # so we filter duplicate approved files for only the latest file.
    def coalesce_files_for_same_object(approved_files)
      latest_approved_files_hash = {}
      approved_files.each do |file_path|
        path_without_updated, updated_at = extract_updated_from_file_path(file_path)
        max_updated_at = [updated_at.to_i, latest_approved_files_hash[path_without_updated].to_i].max
        latest_approved_files_hash[path_without_updated] = max_updated_at
      end
      latest_approved_files_hash.map { |p, u| add_updated_to_file_path(p, u) }
    end

    # Get the translations for a given file_path and language,
    # and return it in the format:
    # { attribute_key: translation_string }
    # for every attribute in the translation file
    def translations_for_file!(file_path, language)
      raw_translations = @client.export_file(file_path, language)
      raw_translations.map do |k, phrases|
        # The phrases are split by sentences, and newline characters.
        # For sentence breaks, we join phrases by adding a space,
        # else we just append the phrase for newline characters.
        full_translation = phrases.inject do |full_phrase, phrase|
          if %w[\r\n, \n].include? phrase
            full_phrase + phrase
          else
            "#{full_phrase} #{phrase}"
          end
        end

        [k, full_translation]
      end.to_h
    end

  end
end
