module I18nSonder
  class UploadSourceStrings
    attr_reader :model

    UPLOAD_TRANSLATION_DELAY = (ENV["UPLOAD_FOR_TRANSLATION_DELAY_MIN"] || 5).minutes

    def initialize(model)
      @model = model
    end

    def upload(locale, options = {})
      return unless should_upload_for_translation?(locale)

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

    # Only upload for translation if:
    # 1) we are writing content in the default locale
    # 2) there is an ID present for the model
    # 3) if this model is allowed for translation
    def should_upload_for_translation?(locale)
      is_default_locale = locale == I18n.default_locale

      model_id_present = model[:id].present?

      # Check if model has the method defined and if it evaluates to true
      model_allowed_for_translation = !model.class.method_defined?(:allowed_for_translation?) ||
          model.allowed_for_translation?

      is_default_locale && model_id_present && model_allowed_for_translation
    end
  end
end
