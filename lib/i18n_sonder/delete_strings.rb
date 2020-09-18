module I18nSonder
  class DeleteStrings
    attr_reader :instance

    def initialize(instance)
      @instance = instance
    end

    def delete
      model = instance.class.name
      id = instance.id
      localization_provider = I18nSonder.localization_provider
      languages_to_translate = I18nSonder.languages_to_translate
      synced_translations = { model => { id => [languages_to_translate] } }
      cleanup_result = localization_provider.cleanup_translations(
        synced_translations,
        languages_to_translate
      )
      handle_failure(cleanup_result.failure)
    end

    private

    def handle_failure(exception)
      if exception.is_a? Exception
        @logger.error("[#{self.class.name}] #{exception}")
      end
    end
  end
end
