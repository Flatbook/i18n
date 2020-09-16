require "spec_helper"

RSpec.describe I18nSonder::UploadHelpers do

  let(:worker_class_mock) {
    class_double(I18nSonder::Workers::UploadSourceStringsWorker).as_stubbed_const(transfer_nested_constants: true)
  }
  let(:id) { 1 }
  let(:attribute_params) { { "title" => {}, "content" => { split_sentences: false } } }
  let(:namespace) { nil }
  let(:options) { { translated_attribute_params: attribute_params, namespace: namespace } }
  let(:instance) { Post.new(id: id, title: "T1", content: "some content", published: true) }

  describe "#get_translated_attribute_params" do
    it "returns the right params for each attribute" do
    end
  end

  describe "#namespace" do
    subject(:namespace) { described_class.namespace(instance) }

    context "when namespace is defined" do
      let(:namespace) { ["dummy_namespace"] }
      before do
        class Post < ActiveRecord::Base
          def namespace_for_translation; ["dummy_namespace"]; end
        end
      end

      it "returns the model's namespace" do
        expect()
      end
    end

    context "when namespace is undefined" do
      it "returns nil" do
      end
    end
  end

  describe "#should_upload_for_translation?" do
    # instance without ID
    context "when instance has an id" do
      let(:instance) { Post.new(title: "T1", content: "some content", published: true) }
    end

    context "when instance doesn't have an id" do
    end

    context "when is a new value" do
    end

    context "when not a new value" do
    end

    context "when writing in non-default locale" do
      before do
        I18n.locale = :fr
        I18n.default_locale = :en
      end

      it "returns true if the content should be translated" do
        expect().to_be(false)
      end
    end

    # it "returns true if the content should be translated" do
    #   expect(worker_class_mock).not_to receive(:perform_in)
    #   instance.save!
    # end

    context "when writing in default locale" do
    end

    context "when model allowed for translation" do
      before do
        class Post < ActiveRecord::Base
          def allowed_for_translation?; true; end
        end
      end
    end

    context "when model not allowed for translation" do
    end
  end
end
