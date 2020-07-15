require 'mobility'

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

      UPLOAD_TRANSLATION_DELAY = (ENV["UPLOAD_FOR_TRANSLATION_DELAY_MIN"] || 5).minutes

      def write(locale, value, options = {})
        if should_upload_for_translation?(model, locale, value, attribute)
          # Get translated attributes, and each attribute's params for uploading translations
          translated_attribute_names = model_class.translated_attribute_names
          translated_attribute_params = {}
          translated_attribute_names.each do |attribute_name|
            upload_options = model.public_send("#{attribute_name}_backend").options[:upload_for_translation]
            translated_attribute_params[attribute_name] = upload_options.is_a?(Hash) ? upload_options : {}
          end

          # Asynchronously upload attributes for translations
          # Include a delay so that multiple edits to the same object can be 'de-duped' in the async job.
          I18nSonder::Workers::UploadSourceStringsWorker.perform_in(
              UPLOAD_TRANSLATION_DELAY, model.class.name, model[:id], translated_attribute_params
          )
        end

        super
      end

      private

      # Only upload for translation if:
      # 1) we are writing content in the default locale
      # 2) the new value being written is different to the already existing value.
      # 3) there is an ID present for the model
      # 4) if this model is allowed for translation
      def should_upload_for_translation?(model, locale, value, attribute)
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
