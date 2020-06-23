require 'sidekiq'
require "mobility"

module I18nSonder
  module Workers
    class UploadSourceStringsWorker
      include Sidekiq::Worker

      sidekiq_options retry: 2

      def initialize
        @logger = I18nSonder.logger
        @log_pre = "[I18nSonder::UploadSourceStringsWorker]"
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
          attributes_to_translate = handle_duplicates(
              object,
              klass,
              object.attributes.slice(*translated_attribute_params.keys)
          )

          @logger.info("#{@log_pre} Uploading attributes #{attributes_to_translate.keys} to translate for #{object_type} #{object_id}")
          result = localization_provider.upload_attributes_to_translate(
              object_type, object_id.to_s, updated_at, attributes_to_translate, translated_attribute_params
          )
          handle_failure(result.failure)
        else
          @logger.error("#{@log_pre} Can't find #{object_type} #{object_id} to send for translation")
        end
      end

      def handle_failure(exception)
        if exception.is_a? Exception
          @logger.error("#{@log_pre} #{exception}")
        end
      end

      private

      # Look for duplicates of any of the +attributes_to_translate+, and update this model with valid duplicates.
      # Filter down +attributes_to_translate+ to only the attribute-value pairs that don't have duplicate translations
      # in all of the +I18nSonder.languages_to_translate+, since we do not need to upload those for translation.
      def handle_duplicates(object, klass, attributes_to_translate)
        locales_to_translate = I18nSonder.languages_to_translate.reject { |l| l == I18n.default_locale }.to_set

        duplicates = duplicate_translations2(klass, attributes_to_translate)

        duplicate_attrs_to_locales = attributes_to_translate.map { |a, _| [a, []] }.to_h

        # require 'pry'
        # binding.pry
        duplicates.each do |locale, translations|
          unless translations.empty?
            Mobility.with_locale(locale) do
              @logger.info("#{@log_pre} Updating #{klass} #{object.id} with duplicate #{locale} translations for #{translations.keys}")
              object.update(translations)
            end
          end

          translations.each do |attr, _|
            duplicate_attrs_to_locales[attr].append(locale)
          end
        end

        attributes_to_translate.select do |attr, _|
          locales_to_translate != duplicate_attrs_to_locales[attr].map(&:to_sym).to_set
        end
      end

      # Look through all other models for translations of the same attribute-value pairs that need translation.
      # Return those duplicates as a hash:
      # { fr: { attribute1: "..." }, es: { attribute1: "..." }, ... }
      #
      # Valid translations are those where:
      # 1) the attribute-values are equal for the model we are updating and the model we are comparing
      # 2) the translation isn't stale (its updated time is after the translatable object's updated time)
      #
      # If there are multiple translations, take the one with the latest updated_at timestamp.
      def duplicate_translations2(klass, attributes_to_translate)
        attributes_to_translate.inject({}) do |translations_by_locale, (attr, value)|
          duplicates = klass.joins("as k INNER JOIN #{translation_table_name(attr)} as t "\
                    "ON t.translatable_id = k.id "\
                    "AND t.translatable_type = '#{klass}' "\
                    "AND t.key = '#{attr}'")
                           .select("DISTINCT ON (t.locale) t.locale, t.value")
                           .where("k.#{attr} = ?", value)
                           .where("date_trunc('second', t.updated_at) >= date_trunc('second', k.updated_at)")
                           .order("t.locale, t.updated_at desc")

          translations_by_locale.deep_merge(
              duplicates.map { |d| [d.locale, { attr => d.value }] }.to_h
          )
        end
      end

      # Note: This method for getting the translation table name for a given attribute
      # is specific to the Key-Value Mobility backend.
      def translation_table_name(attribute)
        klass.mobility_backend_class(attribute).class_name.arel_table.name
      end
    end
  end
end
