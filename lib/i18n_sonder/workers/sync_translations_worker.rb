require 'sidekiq'
require 'i18n_sonder/workers/sync_translations'

module I18nSonder
  module Workers
    class SyncTranslationsWorker
      include Sidekiq::Worker
      include I18nSonder::Workers::SyncTranslations

      sidekiq_options retry: false

      def initialize
        @logger = I18nSonder.logger
      end

      def perform(languages = nil)
        sync(approved_translations_only: false, languages: languages)
      end
    end
  end
end
