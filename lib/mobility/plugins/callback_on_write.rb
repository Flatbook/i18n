require 'mobility'
require 'i18n_sonder/callback_on_write'

module Mobility
  module Plugins
    module CallbackOnWrite
      extend Plugin

      class << self
        def apply(attributes, option)
          return unless option
          # include the write instance method so that we override the backend's write method
          attributes.backend_class.include self
        end
      end

      def write(locale, value, options = {})
        return unless should_execute_callback?(value, attribute, locale)

        super
        I18nSonder::CallbackOnWrite.trigger.call(model, locale)
      end

      private

      # Only execute callback if:
      # 1) the new value being written is different to the already existing value in the context of the locale
      # 2) the locale is not the same as the default locale
      def should_execute_callback?(value, attribute, locale)
        Mobility.with_locale(locale) do
          old_value = model.read_attribute(attribute)

          value != old_value && locale != I18n.default_locale
        end
      end
    end

    register_plugin(:callback_on_write, CallbackOnWrite)
  end
end
