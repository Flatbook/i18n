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

      def perform
        sync(approved_translations_only: true)
      end
    end
  end
end
