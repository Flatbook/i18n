require 'mobility'
require 'i18n_sonder/upload_source_strings'

module Mobility
  module Plugins
    module UploadForTranslation
      class << self
        def apply(attributes, option)
          return unless option
          # include the write instance method so that we override the backend's write method
          attributes.backend_class.include self
        end
      end

      def write(locale, value, options = {})
        return unless should_upload_for_translation?(locale, value, attribute)

        I18nSonder::UploadSourceStrings.new(model).upload

        super
      end

      private

      # Only upload for translation if:
      # 1) we are writing content in the default locale
      # 2) the new value being written is different to the already existing value.
      # 3) there is an ID present for the model
      # 4) if this model is allowed for translation
      def should_upload_for_translation?(locale, value, attribute)
        is_default_locale = locale == I18n.default_locale

        old_value = model.read_attribute(attribute)
        is_different_new_value = value != old_value

        model_id_present = model[:id].present?

        # Check if model has the method defined and if it evaluates to true
        model_allowed_for_translation = !model.class.method_defined?(:allowed_for_translation?) ||
            model.allowed_for_translation?

        is_default_locale && is_different_new_value && model_id_present && model_allowed_for_translation
      end
    end
  end
end
