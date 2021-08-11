require "spec_helper"
require 'mobility'

class DummyI18nCallback
  def self.dummy_callback(model_name, model_id, locale); end
end

# NOTE: Callback on write tests are causing other tests to fail.
# We don't use this right now, so we will temporarily disable this until needed and fixed.
RSpec.describe Mobility::Plugins::CallbackOnWrite do
  let(:id) { 1 }
  let(:locale) { :fr }
  let(:default_locale) { :en }
  let(:instance) { Post.new(id: id, title: "T1", content: "some content", published: true) }

  before do
    I18nSonder::CallbackOnWrite.register do |model, locale|
        DummyI18nCallback.dummy_callback(model.class.name, model.id, locale)
    end

    I18n.default_locale = default_locale
  end

  xcontext "when locale is default" do
    it "does not trigger the registered callback block" do
      expect(I18nSonder::CallbackOnWrite.trigger).not_to receive(:call)
      instance.save!
    end

    it "does not execute the callback method" do
      expect(DummyI18nCallback).not_to receive(:dummy_callback)
      instance.save!
    end
  end

  xcontext "when locale is not default" do
    it "triggers the registered callback block" do
      expect(I18nSonder::CallbackOnWrite.trigger).to receive(:call)
      instance.save!
      I18n.locale = locale
      instance.update!(content: "new content")
    end

    it "does execute the callback method" do
      expect(DummyI18nCallback).to receive(:dummy_callback).with(instance.class.name, instance.id, locale)
      instance.save!
      I18n.locale = locale
      instance.update!(content: "new content")
    end
  end
end
