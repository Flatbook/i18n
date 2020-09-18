module I18nSonder
  class DeleteStrings
    attr_reader :instance

    def initialize(instance)
      @instance = instance
    end

    def delete
      return if instance.blank?

      localization_provider = I18nSonder.localization_provider
      cleanup_result = localization_provider.delete_source_files_for_model(instance)
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
