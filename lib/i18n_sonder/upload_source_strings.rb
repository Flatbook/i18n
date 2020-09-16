module I18nSonder
  class UploadSourceStrings
    include UploadHelpers

    def perform(model, options = {})
      # TOOD: Don't need to check if shoud_upload_for_translation?
      # since most of the time can assume this is triggered when a unit is first added to
      # return unless should_upload_for_translation?(model, locale, value, attribute)

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
    end
  end
end
