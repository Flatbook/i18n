# This rake task takes in a model name as a string. It is case sensitive.
# So, a model class named "Foo" will error if "foo" is passed in as the argument.
# For models that are namespaced, e.g. "Foo::BarBaz",
# the string argument would be "Foo_BarBaz".
namespace :i18n_sonder do
  desc "Upload the source strings for all objects of a given model type for translation"
  task :upload_source_strings_for_translation, [:model_name] => :environment do |_task, args|

    if args[:model_name].present?
      klasses = [args[:model_name].constantize]
    else
      # We get all DIRECT subclasses of ApplicationRecord, rather than all descendents
      # since the table containing source strings will be a direct subclass of
      # ActiveRecord. We don't need to process derived models.
      klasses = ApplicationRecord.subclasses.select { |m| m.included_modules.include?(Mobility::ActiveRecord) }
    end

    uploader = I18nSonder::Workers::UploadSourceStringsWorker.new

    klasses.each do |klass|
      Rails.logger.info("[upload_source_strings_for_translation] Beginning upload for #{klass}")
      total = 0

      klass.in_batches.each do |batch|
        batch.each do |obj|
          # Check if model has the method defined and if it evaluates to true
          model_allowed_for_translation = !klass.method_defined?(:allowed_for_translation?) ||
              obj.allowed_for_translation?

          if model_allowed_for_translation
            # Get translated attributes, and each attribute's params for uploading translations
            translated_attribute_names = klass.translated_attribute_names
            translated_attribute_params = {}
            translated_attribute_names.each do |attribute_name|
              upload_options = obj.public_send("#{attribute_name}_backend").options[:upload_for_translation]
              translated_attribute_params[attribute_name] = upload_options.is_a?(Hash) ? upload_options : {}
            end

            namespace = obj.namespace_for_translation.compact if klass.method_defined?(:namespace_for_translation)

            uploader.perform(
                obj.class.name,
                obj[:id],
                {
                  translated_attribute_params: translated_attribute_params,
                  namespace: namespace
                }
            )
          end
        end

        total += batch.count
        Rails.logger.info("[upload_source_strings_for_translation] Uploaded source strings for #{total} #{klass} objects")
      end
    end
  end
end
