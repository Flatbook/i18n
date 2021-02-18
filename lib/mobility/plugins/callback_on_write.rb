require 'mobility'
require 'i18n_sonder/execute_callback_on_write'

module Mobility
  module Plugins
    module CallbackOnWrite
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
        I18nSonder::ExecuteCallbackOnWrite.callback.call(model, locale)
      end

      private

      # Only execute callback if:
      # 1) the new value being written is different to the already existing value
      def should_execute_callback?(value, attribute, locale)
        old_value = model.read_attribute(attribute)

        value != old_value && locale != I18n.default_locale
      end
    end
  end
end
