source "https://rubygems.org"

# Specify your gem's dependencies in i18n_sonder.gemspec
gemspec

group :development, :test do
  if ENV['RAILS_VERSION'] == '5.0'
    gem 'activerecord', '>= 5.0', '< 5.1'
  elsif ENV['RAILS_VERSION'] == '4.2'
    gem 'activerecord', '>= 4.2.6', '< 5.0'
  elsif ENV['RAILS_VERSION'] == '5.1'
    gem 'activerecord', '>= 5.1', '< 5.2'
  elsif ENV['RAILS_VERSION'] == 'latest'
    gem 'activerecord', '>= 6.0.0.beta1'
  else # Default is Rails 5.2
    gem 'activerecord', '>= 5.2.0', '< 5.3'
    gem 'railties', '>= 5.2.0.rc2', '< 5.3'
  end

  gem 'pry'
  gem 'pry-byebug'
end