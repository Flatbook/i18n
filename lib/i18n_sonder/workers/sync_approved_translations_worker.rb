require 'sidekiq'

module I18nSonder
  module Workers
    class SyncApprovedTranslationsWorker
      include Sidekiq::Worker
      include I18nSonder::Workers::SyncTranslations

      sidekiq_options retry: 2

      def initialize
        @logger = I18nSonder.logger
      end

      def perform(languages = nil)
        sync(approved_translations_only: true, languages: languages)
      end
    end
  end
end
