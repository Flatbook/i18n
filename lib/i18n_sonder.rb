require "i18n_sonder/version"
require "i18n_sonder/configuration"
require "i18n_sonder/logger"
require 'crowdin/adapter'
require "mobility/backends/default_locale_optimized_key_value"
require "mobility/plugins/locale_optimized_query"
require "i18n_sonder/workers/sync_approved_translations_worker"

module I18nSonder
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      @logger ||= Logger.new
    end

    def localization_provider
      @localization_provider ||= CrowdIn::Adapter.new(
          CrowdIn::Client.new(
              api_key: I18nSonder.configuration.crowdin_api_key,
              project_id: I18nSonder.configuration.crowdin_project_id
          )
      )
    end
  end
end
