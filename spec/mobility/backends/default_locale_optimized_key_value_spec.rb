require "spec_helper"
require "mobility/backends/default_locale_optimized_key_value"

RSpec.describe Mobility::Backends::DefaultLocaleOptimizedKeyValue do

  before do
    I18n.default_locale = :en
    Mobility.configure do |config|
      config.default_backend = :default_locale_optimized_key_value
    end

    class Post < ActiveRecord::Base
      extend Mobility
      translates :title, type: :string
      translates :content, type: :text, fallbacks: { fr: :en }
    end
  end

  let(:instance) { Post.new(title: "T1", content: "some content", published: true) }

  context "if content is set in default locale" do
    let(:content) { "new content" }

    before do
      I18n.locale = I18n.default_locale
      instance.content = content
      instance.save!
    end

    it "writes go to model's table", aggregate_failures: true do
      mobility_sql = "select count(*) from mobility_text_translations"
      model_sql = "select content from posts where id = #{instance.id}"
      expect(ActiveRecord::Base.connection.exec_query(mobility_sql).rows[0][0]).to eq 0
      expect(ActiveRecord::Base.connection.exec_query(model_sql).rows[0][0]).to eq content
    end

    it "reads are from model's table" do
      expect(instance.content).to eq content
    end

    it "reads for other locales fallback to default locale if empty" do
      I18n.locale = I18n.default_locale == :en ? :fr : :en
      expect(instance.content).to eq content
    end
  end

  context "if content is set in a non-default locale" do
    let(:content) { "new content" }

    before do
      I18n.locale = I18n.default_locale == :en ? :fr : :en
      instance.content = content
      instance.save!
    end

    it "writes go to translations table", aggregate_failures: true do
      mobility_sql = "select count(*) from mobility_text_translations"
      model_sql = "select content from posts where id = #{instance.id}"
      expect(ActiveRecord::Base.connection.exec_query(mobility_sql).rows[0][0]).to eq 1
      expect(ActiveRecord::Base.connection.exec_query(model_sql).rows[0][0]).to eq nil
    end

    it "reads are from translations table" do
      expect(instance.content).to eq content
    end

    it "reads are empty for other locales since default locale is not set" do
      I18n.locale = I18n.locale == :fr ? :en : :fr
      expect(instance.content).to eq nil
    end
  end
end
