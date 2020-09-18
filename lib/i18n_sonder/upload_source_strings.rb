module I18nSonder
  class UploadSourceStrings
    attr_reader :model

    UPLOAD_TRANSLATION_DELAY = (ENV["UPLOAD_FOR_TRANSLATION_DELAY_MIN"] || 5).minutes

    def initialize(model)
      @model = model
    end

    def upload(options = {})
      # Asynchronously upload attributes for translations
      # Include a delay so that multiple edits to the same object can be 'de-duped' in the async job.
      I18nSonder::Workers::UploadSourceStringsWorker.perform_in(
        UPLOAD_TRANSLATION_DELAY,
        model.class.name,
        model[:id],
        {
          translated_attribute_params: translated_attribute_params,
          namespace: namespace,
          handle_duplicates: I18nSonder.apply_duplicate_translations_on_upload
        }
      )
    end

    private

    def translated_attribute_params
      # Get translated attributes and each attribute's params for uploading translations
      translated_attribute_names = model.translated_attribute_names
      translated_attribute_params = {}
      translated_attribute_names.each do |attribute_name|
        upload_options = model.public_send("#{attribute_name}_backend").options[:upload_for_translation]
        translated_attribute_params[attribute_name] = upload_options.is_a?(Hash) ? upload_options : {}
      end

      translated_attribute_params
    end

    def namespace
      return unless model.class.method_defined?(:namespace_for_translation)

      model.namespace_for_translation.compact
    end
  end
end
