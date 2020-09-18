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
        return unless should_upload_for_translation?(value, attribute)

        I18nSonder::UploadSourceStrings.new(model).upload(locale)

        super
      end

      private

      # Only upload for translation if:
      # 1) the new value being written is different to the already existing value
      def should_upload_for_translation?(value, attribute)
        old_value = model.read_attribute(attribute)

        value != old_value
      end
    end
  end
end
