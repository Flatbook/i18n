require "i18n_sonder/version"
require "crowdin/client"
require "mobility/backends/default_locale_optimized_key_value"
require "mobility/plugins/locale_optimized_query"

module I18nSonder
  class Error < StandardError; end
end
