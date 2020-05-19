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

      UPLOAD_TRANSLATION_DELAY = 5.minutes

      def write(locale, value, options = {})
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
        super
      end
    end
  end
end
