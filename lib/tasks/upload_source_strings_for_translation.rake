# This rake task takes in a model name as a string. It is case sensitive.
# So, a model class named "Foo" will error if "foo" is passed in as the argument.
# For models that are namespaced, e.g. "Foo::BarBaz",
# the string argument would be "Foo_BarBaz".
namespace :i18n_sonder do
  desc "Upload the source strings for all objects of a given model type for translation"
  task :upload_all_source_strings, [:model_name] => :environment do |_task, args|

    if args[:model_name].present?
      klasses = [args[:model_name].constantize]
    else
      # We get all DIRECT subclasses of ApplicationRecord, rather than all descendents
      # since the table containing source strings will be a direct subclass of
      # ActiveRecord. We don't need to process derived models.
      klasses = ApplicationRecord.subclasses.select { |m| m.included_modules.include?(Mobility::ActiveRecord) }
    end

    klasses.each do |klass|
      I18nSonder.logger.info("[upload_source_strings_for_translation] Beginning upload for #{klass}")
      total = 0

      klass.in_batches.each do |batch|
        batch.each do |obj|
          I18nSonder::Upload.new(obj).upload(I18n::default_locale)
        end

        total += batch.count
        I18nSonder.logger.info("[upload_source_strings_for_translation] Uploaded source strings for #{total} #{klass} objects")
      end
    end
  end

  desc "Upload the source strings for a given model name and id"
  task :upload_source_strings_for_object, [:model_name, :model_id] => :environment do |_task, args|

    if !args[:model_name].present? || !args[:model_id].present?
      I18nSonder.logger.error("[upload_source_strings_for_translation] Beginning upload for #{klass}")
    else
      klass = args[:model_name].constantize
      obj = klass.find(args[:model_id])

      I18nSonder.logger.info("[upload_source_strings_for_translation] Uploaded source strings for #{total} #{klass} objects")
      I18nSonder::Upload.new(obj).upload(I18n::default_locale)
    end
  end
end
