require_relative 'lib/i18n_sonder/version'

Gem::Specification.new do |spec|
  spec.name          = "i18n_sonder"
  spec.version       = I18nSonder::VERSION
  spec.authors       = ["sondercom-eng"]
  spec.email         = ["sondercom-eng@sonder.com"]

  spec.summary       = %q{common i18n code for Sonder's apps and services}
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.files         = Dir['{lib/**/*,[A-Z]*}']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'mobility', '>= 0.8.9', '< 1.2.0'
  spec.add_dependency 'rest-client', '~> 2.0'
  spec.add_dependency 'sidekiq'
  spec.add_dependency 'rack', '>= 2.0.6'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'sqlite3', '~> 1.3', '>= 1.3.0'
  spec.add_development_dependency 'database_cleaner', '~> 1.7', '>= 1.7.0'
  spec.add_development_dependency 'webmock'
end
