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
        old_value = model.read_attribute(attribute)

        # Only upload for translation if we are writing content in the default locale,
        # and if the new value being written is different to the already existing value.
        if locale == I18n.default_locale && value != old_value
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
    end
  end
end
