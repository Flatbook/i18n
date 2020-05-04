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

      def write(locale, value, options = {})
        if locale == I18n.default_locale
          model.write_attribute(attribute, value)
        else
          super(locale, value, options)
        end
      end
    end
  end
end
