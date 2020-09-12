class I18nSonder::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/upload_source_strings_for_translation.rake'
  end
end
