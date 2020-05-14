module I18nSonder
  class Logger
    def info(m)
      I18nSonder.configuration.logger&.info(m)
    end

    def error(e)
      I18nSonder.configuration.logger&.error(e)
    end
  end
end
