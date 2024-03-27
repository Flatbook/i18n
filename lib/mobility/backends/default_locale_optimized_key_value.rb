require "mobility"
require "mobility/backends/active_record/key_value"

module Mobility
  module Backends
    # Extend Mobility's KeyValue Backend such that reads and writes to the default locale,
    # in our case English, are made against the native table of the Model, rather
    # than the translation tables.
    class DefaultLocaleOptimizedKeyValue < Mobility::Backends::ActiveRecord::KeyValue
      def read(locale, options = {})
        if locale == I18n.default_locale
          model.read_attribute(attribute)
        else
          super(locale, options)
        end
      end

      # Note, this does not take into account region specific locale differences.
      # For example, if the `locale` is "en-GB", and the default_locale is "en",
      # we treat "en-GB" as the default locale and write to the model's table,
      # rather than to the translation table.
      def write(locale, value, options = {})
        locale_without_region = locale.to_s.split("-").first
        default_locale_without_region = I18n.default_locale.to_s.split("-").first
        if locale_without_region == default_locale_without_region
          model.write_attribute(attribute, value)
        else
          super(locale, value, options)
        end
      end
    end

    register_backend(:default_locale_optimized_key_value, DefaultLocaleOptimizedKeyValue)
  end
end
