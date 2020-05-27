require 'sidekiq'

module I18nSonder
  module Workers
    class SyncApprovedTranslationsWorker
      include Sidekiq::Worker

      sidekiq_options retry: 2

      def initialize
        @logger = I18nSonder.logger
      end

      def perform
        localization_provider = I18nSonder.localization_provider

        successful_syncs = {}
        # Iterate through each language we need to sync
        languages_to_translate = I18n.available_locales.reject { |l| l == I18n.default_locale }
        languages_to_translate.each do |language|
          @logger.info("[I18nSonder::SyncApprovedTranslationsWorker] Fetching translations for #{language}")
          # Fetch translations in the following format
          # {
          #   model: {
          #     id: {
          #       field_1: val1,
          #       field_2: val2
          #     }
          #   }
          # }
          translation_result = localization_provider.translations(language.to_s)
          translations_by_model_and_id = translation_result.success
          handle_failure(translation_result.failure)

          begin
            write_translations(translations_by_model_and_id, language)
          rescue => e
            handle_failure(e)
          else
            # All translations were written successfully in this language
            successful_syncs = process_successful_syncs(translations_by_model_and_id, language, successful_syncs)
          end
        end

        @logger.info("[I18nSonder::SyncApprovedTranslationsWorker] Cleaning up translations")
        cleanup_result = localization_provider.cleanup_translations(successful_syncs, languages_to_translate)
        handle_failure(cleanup_result.failure)
      end

      # Update attributes in given language
      def write_translations(translations_by_model_and_id, language)
        # Write these translations to DB
        translations_by_model_and_id.each do |model_name, translations_by_id|
          translations_by_id.each do |id, translations|
            @logger.info("[I18nSonder::SyncApprovedTranslationsWorker] Writing translations for #{model_name} #{id} in #{language}")
            Mobility.with_locale(language) do
              model_name.constantize.update(id, translations)
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
          @logger.error("[I18nSonder::SyncApprovedTranslationsWorker] #{exception}")
        end
      end
    end
  end
end
