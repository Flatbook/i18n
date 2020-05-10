require 'crowdin/client'
require 'crowdin/file_methods'
require 'crowdin/translation_methods'

module CrowdIn
  class Adapter
    include CrowdIn::FileMethods
    include CrowdIn::TranslationMethods

    # :success - Hash of successful results, e.g. translations
    # :failure - Error containing details of the specific error
    ReturnObject = Struct.new(:success, :failure)

    def initialize(client)
      @client = client
    end

    # Given a language, fetch approved translations.
    # Returns Struct of approved translations hash, and/or failures.
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
    # Failures can be:
    # 1) +CrowdIn::Client::Errors::Error+ if we fail to fetch the translation status of files
    # 2) +CrowdIn::FileMethods::FilesError+ if any individual files fail on export
    def translations(language)
      begin
        file_status_list = @client.language_status(language)
      rescue CrowdIn::Client::Errors::Error => e
        ReturnObject.new({}, e)
      else
        # Fetch list of approved translation file paths
        approved_file_ids = file_status_list.select { |f| f['approvalProgress'] == 100 }.map { |f| f['file_id'] }

        # Fetch translations for each approved file
        to_return = translations_for_files(approved_file_ids, language)
        if to_return.failure.present? && to_return.failure.is_a?(CrowdIn::FileMethods::FilesError)
          @files_to_cleanup = approved_file_ids - to_return.failure.errors_by_file.keys
        else
          @files_to_cleanup = approved_file_ids
        end
        to_return
      end
    end

    def translations_for_file(file_id, language)
      translations_for_files([file_id], language)
    end

    # Delete all the approved translation files, stored in @approved_files.
    # This should be called after we successfully persist the approved translations.
    #
    # Returns +CrowdIn::FileMethods::FilesError+ with failed files for those that fail deletion.
    def cleanup_translations
      if @files_to_cleanup.present?
        failed_files = safe_file_iteration(@files_to_cleanup) { |file_id| @client.delete_file(file_id) }
      else
        failed_files = nil
      end
      ReturnObject.new(nil, failed_files)
    end

    def cleanup_file(file_id)
      failed_files = safe_file_iteration([file_id]) { |id| @client.delete_file(id) }
      ReturnObject.new(nil, failed_files)
    end

    private

    def translations_for_files(file_ids, language)
      translations = {}
      failed_files = safe_file_iteration(file_ids) do |file_id|
        translations.deep_merge!(translations_for_file!(file_id, language))
      end

      ReturnObject.new(translations, failed_files)
    end

    # Get the translations for a given file_id and language,
    # and return it in the format:
    # {
    #   model: {
    #     id: {
    #       field_1: val1,
    #       field_2: val2
    #     }
    #   }
    # }
    #
    # Translation files are in the format:
    # {
    #   model: {
    #     id: {
    #       updated_at: {
    #         field_1: [ translated_sentence_1, translated_sentence_2, ... ]
    #       }
    #     }
    #   }
    # }
    # so we resolve the latest attribute_keys and connect sentences together
    # to return translations.
    def translations_for_file!(file_id, language)
      raw_translations = @client.export_file(file_id, language)
      raw_translations.map do |model_type, translations_by_id|
        [
            model_type,
            translations_by_id.map do |id, translations_by_updated|
              [id, latest_translations(translations_by_updated)]
            end.to_h
        ]
      end.to_h
    end

    # Given input:
    # {
    #   updated_at: {
    #     field_1: [ translated_sentence_1, translated_sentence_2, ... ]
    #   }
    # }
    # get the latest translations, and coalesce translations split into sentence arrays
    # into a single translation.
    def latest_translations(translations_by_updated)
      # iterate through updated_at timestamps in ascending order, and apply translations.
      # This way the latest translations overwrite any older ones.
      translations = {}
      updated_asc = translations_by_updated.keys.map(&:to_i).sort
      updated_asc.each do |updated|
        next_translations = translations_by_updated[updated.to_s]
        translations.merge!(next_translations)
      end
      join_sentences(translations)
    end
  end
end
