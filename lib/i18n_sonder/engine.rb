module I18nSonder
  class Engine < ::Rails::Engine
    isolate_namespace I18nSonder

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
