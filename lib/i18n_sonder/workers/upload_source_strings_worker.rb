require 'sidekiq'
require "mobility"

module I18nSonder
  module Workers
    class UploadSourceStringsWorker
      include Sidekiq::Worker

      sidekiq_options retry: 2

      def initialize
        @logger = I18nSonder.logger
      end

      # Find the object, given type and id, and extract all of the required attributes.
      # Then submit those params for translation. We fetch all the params here, rather than
      # have it passed in as arguments so as to minimize race conditions and obtain as up-to-date
      # information regarding attributes as possible.
      #
      # Any attribute key of an object that requires translation must appear as a key in the
      # +translated_attribute_params+ hash. The value in this hash is any relevant params on how
      # to upload these source strings for translations. The value can be empty for default values.
      def perform(object_type, object_id, translated_attribute_params)
        localization_provider = I18nSonder.localization_provider

        # Find the object and all its localized attributes
        klass = object_type.constantize
        object = klass.find(object_id)
        if object.present?
          updated_at = object.has_attribute?(:updated_at) ? object.updated_at.to_i : nil
          attributes_to_translate = object.attributes.slice(*translated_attribute_params.keys)

          @logger.info("[I18nSonder::UploadSourceStringsWorker] Uploading attributes to translate for #{object_type} #{object_id}")
          result = localization_provider.upload_attributes_to_translate(
              object_type, object_id.to_s, updated_at, attributes_to_translate, translated_attribute_params
          )
          handle_failure(result.failure)
        else
          @logger.error("[I18nSonder::UploadSourceStringsWorker] Can't find #{object_type} #{object_id} to send for translation")
        end
      end

      def handle_failure(exception)
        if exception.is_a? Exception
          @logger.error("[I18nSonder::UploadSourceStringsWorker] #{exception}")
        end
      end
    end
  end
end
