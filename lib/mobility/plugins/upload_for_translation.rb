require 'mobility'
require 'i18n_sonder/upload_helpers'

module Mobility
  module Plugins
    module UploadForTranslation
      include I18nSonder::UploadHelpers

      class << self
        def apply(attributes, option)
          return unless option
          # include the write instance method so that we override the backend's write method
          attributes.backend_class.include self
        end
      end

      def write(locale, value, options = {})
        return unless should_upload_for_translation?(model, locale, value, attribute)

        # Asynchronously upload attributes for translations
        # Include a delay so that multiple edits to the same object can be 'de-duped' in the async job.
        I18nSonder::Workers::UploadSourceStringsWorker.perform_in(
            UPLOAD_TRANSLATION_DELAY,
            model.class.name,
            model[:id],
            {
              translated_attribute_params: get_translated_attribute_params(model),
              namespace: namespace(model)
            }
        )

        super
      end
    end
  end
end
