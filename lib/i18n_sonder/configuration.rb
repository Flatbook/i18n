module I18nSonder
  class Configuration
    attr_accessor :crowdin_api_key, :crowdin_project_id, :logger, :languages_to_translate

    def initialize
      self.crowdin_api_key = nil
      self.crowdin_project_id = nil
      self.logger = nil
      self.languages_to_translate = nil
    end
  end
end
