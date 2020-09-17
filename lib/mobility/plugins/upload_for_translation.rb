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
        I18nSonder::UploadSourceStrings.new(model).upload(locale, value, attribute)

        super
      end
    end
  end
end
