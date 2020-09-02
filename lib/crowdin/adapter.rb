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

    # Upload an object's attributes to CrowdIn for translation.
    # +object_type+ - fully qualified model name, e.g. Object::One
    # +object_id+ - id for the model object
    # +updated_at+ - the last updated timestamp,
    # which we store in the CrowdIn translation file and used to resolve duplicates.
    # Can be nil when the object has no +updated_at+ column.
    # +attributes+ - key value pairs of attribute name to attribute values in english to translate
    # +options+
    #   +attribute_params+ - optional params per attribute_key.
    #     +attribute_params[:split_into_sentences]+ - indicates whether to split this attribute
    #     value into sentences on upload to CrowdIn. This allows for greater de-duplication,
    #     but can't be done with text that is heavily templated, as an example,
    #     since we can break sentences across template format tags.
    #   +namespace+ - optional array specifying the directory to upload source strings to.
    #
    # For objects that already have a translation file in CrowdIn, we simple replace its content if the current
    # +updated_at+ timestamp is later than what is present in CrowdIn.
    #
    # The returned +ReturnObject.failure+ is non-empty if there are errors.
    # The returned +ReturnObject.success+ is +nil+ regardless of success/failure.
    def upload_attributes_to_translate(object_type, object_id, updated_at, attributes, options)
      # Find the CrowdIn File corresponding to object.
      to_return = ReturnObject.new(nil, nil)
      return to_return if attributes.empty?
      begin
        file_name = file_name(object_type, object_id)
        file_base_name = File.basename(file_name, ".*")
        file_id = @client.find_file_by_name(file_base_name)
        file_content = file_content_for_translations(
          object_type, object_id, updated_at, attributes, options[:translated_attribute_params]
        )

        if file_id && updated_at.present?
          # If file exists, check updated timestamps, and update only if we don't have the latest timestamp's attributes
          attributes = @client.download_source_file(file_id)
          attributes_by_updated = attributes.dig(object_type, object_id)

          if attributes_by_updated.present?
            # we don't need to update the attributes if there are attributes for the same or later updated_at timestamp
            latest_already_exists = attributes_by_updated.select { |u, _| u.to_i >= updated_at.to_i }.present?

            @client.update_file(file_id, file_content) unless latest_already_exists
          else
            e = CrowdIn::FileMethods::FilesError.new({ file_id => "Could not find #{object_type} #{object_id}" })
            to_return.failure = e
          end
        else
          # If file doesn't exist for object, create it with attributes to translate
          if options.key?(:namespace)
            dir_name = options[:namespace].last
            directory = @client.find_directory_by_name(dir_name)
            directory = @client.add_directory(dir_name) unless directory.present?
            @client.add_file(file_name, file_content, directory)
          else
            @client.add_file(file_name, file_content)
          end
        end
      rescue CrowdIn::Client::Errors::Error => e
        ReturnObject.new(nil, e)
      else
        to_return
      end
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
        translations_for_files(approved_file_ids, language)
      end
    end

    def translations_for_file(file_id, language)
      translations_for_files([file_id], language)
    end

    # Given a hash of objects that have been successfully sync'd, and all the +available_locales+,
    # delete all the source files that have successfully been sync'd in every locale.
    #
    # Returns +CrowdIn::FileMethods::FilesError+ with failed files for those that fail deletion.
    def cleanup_translations(objects_syncd, available_locales)
      sorted_languages = available_locales.sort
      files_to_cleanup = []

      objects_syncd.each do |model_name, successful_languages_by_id|
        successful_languages_by_id.each do |id, successful_languages|
          if sorted_languages == successful_languages.sort
            file_name = file_name(model_name, id)
            file_base_name = File.basename(file_name, ".*")
            files_to_cleanup.append(@client.find_file_by_name(file_base_name))
          end
        end
      end

      if files_to_cleanup.present?
        failed_files = safe_file_iteration(files_to_cleanup) { |file_id| @client.delete_file(file_id) }
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

    def file_content_for_translations(object_type, object_id, updated_at, attributes, attribute_params)
      attributes_to_translate = attributes.inject({}) do |final_hash, (attribute_key, attribute_value)|
        if attribute_params.dig(attribute_key, :split_into_sentences) === true
          final_hash.merge(split_into_sentences(attribute_key => attribute_value))
        else
          final_hash[attribute_key] = attribute_value
          final_hash
        end
      end

      if updated_at.present?
        { object_type => { object_id => { updated_at => attributes_to_translate } } }.to_json
      else
        { object_type => { object_id => attributes_to_translate } }.to_json
      end
    end

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
    # if the model has updated_at, else, it does not have the updated_at key.
    #
    # So, we resolve the latest attribute_keys and connect sentences together
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

    # The input could either be:
    # {
    #   updated_at: {
    #     field_1: [ translated_sentence_1, translated_sentence_2, ... ]
    #   }
    # }
    # or simply:
    # {
    #   field_1: [ translated_sentence_1, translated_sentence_2, ... ]
    # }
    # depending on whether the object has an updated_at column.
    # This gets the latest translations, and coalesce translations split into sentence arrays
    # into a single translation.
    def latest_translations(translations_by_updated)
      # Find out if object has updated by inspecting first key and checking if it is a number.
      # Safe to do under the assumption that object keys are not numeric, but the updated_at timestamp is.
      has_updated = Float(translations_by_updated.keys.first) != nil rescue false

      # iterate through updated_at timestamps in ascending order, and apply translations.
      # This way the latest translations overwrite any older ones.
      if has_updated
        translations = {}
        updated_asc = translations_by_updated.keys.map(&:to_i).sort
        updated_asc.each do |updated|
          next_translations = translations_by_updated[updated.to_s]
          translations.merge!(next_translations)
        end
        join_sentences(translations)
      else
        join_sentences(translations_by_updated)
      end
    end
  end
end
