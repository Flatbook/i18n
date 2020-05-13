require 'sidekiq'

module I18nSonder
  module Workers
    class SyncApprovedTranslationsWorker
      include Sidekiq::Worker

      def initialize
        @localization_provider = I18nSonder.localization_provider
        @logger = I18nSonder.logger
      end

      def perform
        # Iterate through each language we need to sync
        I18n.available_locales.reject { |l| l == I18n.default_locale }.each do |language|
          @logger.info("Fetching translations for #{language}")
          # Fetch translations in the following format
          # {
          #   model: {
          #     id: {
          #       field_1: val1,
          #       field_2: val2
          #     }
          #   }
          # }
          translation_result = @localization_provider.translations(language.to_s)
          translations_by_model_and_id = translation_result.success
          handle_failure(translation_result.failure)

          begin
            write_translations(translations_by_model_and_id, language)

            # Cleanup translations only if they have been successfully persisted
            @logger.info("Cleaning up translations for #{language}")
            cleanup_result = @localization_provider.cleanup_translations
            handle_failure(cleanup_result.failure)
          rescue => e
            handle_failure(e)
          end
        end
      end

      # Update attributes in given language
      def write_translations(translations_by_model_and_id, language)
        # Write these translations to DB
        translations_by_model_and_id.each do |model_name, translations_by_id|
          translations_by_id.each do |id, translations|
            @logger.info("Writing translations for #{model_name} #{id} in #{language}")
            Mobility.with_locale(language) do
              model_name.constantize.update!(id, translations)
            end
          end
        end
      end

      def handle_failure(exception)
        if exception.is_a? Exception
          @logger.error(exception)
        end
      end
    end
  end
end
