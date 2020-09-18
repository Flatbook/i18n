module I18nSonder
  class DeleteStrings
    attr_reader :instance

    def initialize(instance)
      @instance = instance
    end

    def delete
      model_name = instance.class.name
      id = instance.id
      localization_provider = I18nSonder.localization_provider
      cleanup_result = localization_provider.delete_source_files_for_model(model_name, id)
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
