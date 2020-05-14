module I18nSonder
  class Configuration
    attr_accessor :crowdin_api_key, :crowdin_project_id, :logger

    def initiailize
      self.crowdin_api_key = nil
      self.crowdin_project_id = nil
      self.logger = nil
    end
  end
end
