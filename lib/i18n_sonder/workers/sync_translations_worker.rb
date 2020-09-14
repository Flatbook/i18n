require 'sidekiq'
require 'i18n_sonder/workers/sync_translations'

module I18nSonder
  module Workers
    class SyncTranslationsWorker
      include Sidekiq::Worker
      include I18nSonder::Workers::SyncTranslations

      sidekiq_options retry: 2

      def initialize
        @logger = I18nSonder.logger
      end

      def perform
        sync(approved_translations_only: false)
      end
    end
  end
end
