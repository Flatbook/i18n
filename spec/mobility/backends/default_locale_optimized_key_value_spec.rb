require "spec_helper"

RSpec.describe Mobility::Backends::DefaultLocaleOptimizedKeyValue do

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

    context "when performing queries" do
      it "results in default locale should be returned" do
        p = Post.i18n.select(:id, :content).where(id: instance.id).first
        expect(p.content).to eq content
      end

      context "for non-default locale" do
        before do
          I18n.locale = I18n.default_locale == :en ? :fr : :en
        end

        it "fallsback to default locale if no content in non-default locale" do
          p = Post.i18n.select(:id, :content).where(id: instance.id).first
          expect(p.content).to eq content
        end

        it "returns content in non-default locale when it exists" do
          translated_content = "translated content"
          instance.content = translated_content
          instance.save!

          p = Post.i18n.select(:content).where(id: instance.id).first
          expect(p.content).to eq translated_content
        end
      end
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

    context "when performing queries" do
      it "results in non-default locale should be returned" do
        p = Post.i18n.select(:id, :content).where(id: instance.id).first
        expect(p.content).to eq content
      end

      context "for default locale" do
        before do
          I18n.locale = I18n.locale == :fr ? :en : :fr
        end

        it "no results are returned since default locale has no results." do
          p = Post.i18n.select(:id, :content).where(id: instance.id).first
          expect(p.content).to eq nil
        end

        it "returns content in default locale when it exists" do
          translated_content = "default locale content"
          instance.content = translated_content
          instance.save!

          p = Post.i18n.select(:content).where(id: instance.id).first
          expect(p.content).to eq translated_content
        end
      end
    end
  end
end
