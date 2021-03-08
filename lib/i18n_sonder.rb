require 'i18n_sonder/version'
require 'i18n_sonder/configuration'
require 'i18n_sonder/logger'
require 'crowdin/adapter'
require 'mobility/backends/default_locale_optimized_key_value'
require 'mobility/plugins/locale_optimized_query'
require 'mobility/plugins/upload_for_translation'
require 'mobility/plugins/callback_on_write'
require 'i18n_sonder/workers/sync_translations_worker'
require 'i18n_sonder/workers/sync_approved_translations_worker'
require 'i18n_sonder/workers/upsert_translation_worker'
require 'i18n_sonder/workers/upload_source_strings_worker'
require 'i18n_sonder/upload_source_strings'
require 'i18n_sonder/delete_strings'
require 'i18n_sonder/railtie'
require 'i18n_sonder/engine'

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

    # Returns a new CrowdIn Adapter with a new CrowdIn Client.
    def localization_provider
      CrowdIn::Adapter.new(
          CrowdIn::Client.new(
              api_key: I18nSonder.configuration.crowdin_api_key,
              project_id: I18nSonder.configuration.crowdin_project_id
          )
      )
    end

    def languages_to_translate
       config_val = I18nSonder.configuration.languages_to_translate
       config_val.present? ? config_val : I18n.available_locales
    end

    def apply_duplicate_translations_on_upload
      config_val = I18nSonder.configuration.apply_duplicate_translations_on_upload
      config_val.present? ? config_val : false
    end
  end
end
