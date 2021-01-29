require 'sidekiq'
require 'i18n_sonder/workers/sync_translations'

module I18nSonder
  module Workers
    class UpsertTranslationWorker
      include Sidekiq::Worker
      include I18nSonder::Workers::SyncTranslations

      sidekiq_options retry: 3

      def initialize
        @logger = I18nSonder.logger
      end

      def perform(language, translation_id, source_string_id)
        localization_provider = I18nSonder.localization_provider
        translation_result = localization_provider.translation_by_id(translation_id, source_string_id)
        process_translation_result(translation_result, language, {})
      end
    end
  end
end
