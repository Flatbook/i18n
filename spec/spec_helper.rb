require "bundler/setup"
require "i18n_sonder"
require "active_record"
require "mobility"
require "pry"

require "database_cleaner"
DatabaseCleaner.strategy = :transaction

ENV['RAILS_VERSION'] ||= "5.2"
ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

I18n.enforce_available_locales = false

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    DatabaseCleaner.start
    I18n.locale = :en
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

class TestSchema < ActiveRecord::Migration[ENV['RAILS_VERSION'].to_f]
  def self.up
    create_table :posts do |t|
      t.string :title
      t.text :content
      t.boolean :published
    end

    create_table :mobility_string_translations do |t|
      t.string  :locale
      t.string  :key
      t.string  :value
      t.integer :translatable_id
      t.string  :translatable_type
      t.timestamps
    end

    create_table :mobility_text_translations do |t|
      t.string  :locale
      t.string  :key
      t.text    :value
      t.integer :translatable_id
      t.string  :translatable_type
      t.timestamps
    end
  end
end

ActiveRecord::Migration.verbose = false
TestSchema.up
