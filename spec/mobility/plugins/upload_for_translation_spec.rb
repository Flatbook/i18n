require "spec_helper"

RSpec.describe Mobility::Plugins::UploadForTranslation do

  let(:worker_class_mock) {
    class_double(I18nSonder::Workers::UploadSourceStringsWorker).as_stubbed_const(transfer_nested_constants: true)
  }
  let(:id) { 1 }
  let(:attribute_params) { { "title" => {}, "content" => { split_sentences: false } } }
  let(:instance) { Post.new(id: id, title: "T1", content: "some content", published: true) }

  it "calls async worker with correct params and delay on creation" do
    # worker will be called twice on creation, once per translatabe field
    expect(worker_class_mock).to(
        receive(:perform_in).with(5.minutes, 'Post', id, attribute_params).exactly(2).times
    )
    instance.save!
  end

  it "calls async worker with correct params and delay on update" do
    # worker will be called twice on creation, and then once on update
    expect(worker_class_mock).to(
        receive(:perform_in).with(5.minutes, 'Post', id, attribute_params).exactly(3).times
    )
    instance.save!
    instance.update!(content: "new content")
  end

  context "for instance without id" do
    let(:instance) { Post.new(title: "T1", content: "some content", published: true) }

    it "does not call async worker" do
      expect(worker_class_mock).not_to receive(:perform_in)
    end
  end

  context "when writing in non-default locale" do
    before do
      I18n.locale = :fr
      I18n.default_locale = :en
    end

    it "should be a no-op" do
      expect(worker_class_mock).not_to receive(:perform_in)
      instance.save!
    end
  end
end
