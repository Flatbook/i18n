module I18nSonder
  module Workers
    module SyncTranslations

      BATCH_SIZE = 500

      def sync(approved_translations_only:)
        localization_provider = I18nSonder.localization_provider

        successful_syncs = {}
        # Iterate through each language we need to sync
        languages_to_translate = I18nSonder.languages_to_translate.reject { |l| l == I18n.default_locale }
        languages_to_translate.each do |language|
          @logger.info("[#{self.class.name}] Fetching translations for #{language}")
          # Fetch translations in the following format
          # {
          #   model: {
          #     id: {
          #       field_1: val1,
          #       field_2: val2
          #     }
          #   }
          # }
          if approved_translations_only
            localization_provider.approved_translations(language.to_s, BATCH_SIZE) do |translation_result_batch|
              successful_syncs = process_translation_result(translation_result_batch, language, successful_syncs)
            end
          else
            localization_provider.translations(language.to_s, BATCH_SIZE) do |translation_result_batch|
              successful_syncs = process_translation_result(translation_result_batch, language, successful_syncs)
            end
          end
        end

        if approved_translations_only
          @logger.info("[#{self.class.name}] Cleaning up translations")
          cleanup_result = localization_provider.cleanup_translations(successful_syncs, languages_to_translate)
          handle_failure(cleanup_result.failure)
        end
      end

      def process_translation_result(translation_result, language, successful_syncs)
        translations_by_model_and_id = translation_result.success
        handle_failure(translation_result.failure)

        write_translations(translations_by_model_and_id, language)

        process_successful_syncs(translations_by_model_and_id, language, successful_syncs)
      end

      def process_translation_result_with_duplicates(translation_result,
                                                     language,
                                                     successful_syncs)
        handle_failure(translation_result.failure)
        success = translation_result.success
        valid_translation_result = success.present? &&
          success.key?('source_text') &&
          success.key?('translation')
        @logger.error("[#{self.class.name}] Invalid translation result") unless valid_translation_result
        return unless valid_translation_result

        translations_by_model_and_id = all_duplicate_translations(
          translation_result.success, language
        )

        write_translations(translations_by_model_and_id, language)

        process_successful_syncs(translations_by_model_and_id, language, successful_syncs)
      end

      def all_duplicate_translations(translations_and_source_text, language)
        translations_by_model_and_id = Hash.new { |h1,k1|
          h1[k1] = Hash.new { |h2,k2| h2[k2] = {} }
        }

        translations_and_source_text['source_text'].each do |model_name, translations_by_id|
          translations_by_id.each do |id, translations|
            translations.each do |attr, value|
              translation = translations_and_source_text.dig(
                'translation', model_name, id, attr
              )

              duplicate_ids = model_name.constantize
                                        .where("#{attr} = ?", value)
                                        .pluck(:id)

              duplicate_ids.each do |duplicate_id|
                duplicate_model = translations_by_model_and_id[model_name]
                duplicate_model[duplicate_id][attr] = translation
              end
            end
          end
        end

        translations_by_model_and_id
      end

      # Update attributes in given language
      def write_translations(translations_by_model_and_id, language)
        # Write these translations to DB
        translations_by_model_and_id.each do |model_name, translations_by_id|
          translations_by_id.each do |id, translations|
            @logger.info("[#{self.class.name}] Writing translations for #{model_name} #{id} in #{language} for following fields: #{translations.keys}")
            begin
              Mobility.with_locale(language) do
                model_name.constantize.update(id, translations)
              end
            rescue => e
              handle_failure(e)
            end
          end
        end
      end

      def process_successful_syncs(translations_by_model_and_id, language, successful_syncs)
        translations_by_model_and_id.each do |model_name, ids|
          ids.keys.each do |id|
            if successful_syncs.dig(model_name, id)
              successful_syncs[model_name][id].append(language)
            elsif successful_syncs.key? model_name
              successful_syncs[model_name][id] = [language]
            else
              successful_syncs[model_name] = { id => [language] }
            end
          end
        end
        successful_syncs
      end

      def handle_failure(exception)
        if exception.is_a? Exception
          @logger.error("[#{self.class.name}] #{exception}")
        end
      end
    end
  end
end
