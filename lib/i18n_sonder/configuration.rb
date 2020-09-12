module I18nSonder
  class Configuration
    attr_accessor :crowdin_api_key, :crowdin_project_id, :logger,
    :languages_to_translate, :apply_duplicate_translations_on_upload

    def initialize
      self.crowdin_api_key = nil
      self.crowdin_project_id = nil
      self.logger = nil
      self.languages_to_translate = nil
      self.apply_duplicate_translations_on_upload = nil
    end
  end
end
