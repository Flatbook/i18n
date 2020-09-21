require 'spec_helper'

RSpec.describe I18nSonder::UploadSourceStrings do
  let(:worker_class_mock) {
    class_double(I18nSonder::Workers::UploadSourceStringsWorker).as_stubbed_const(transfer_nested_constants: true)
  }
  let(:id) { 1 }
  let(:attribute_params) { { 'title' => {}, 'content' => { split_sentences: false } } }
  let(:namespace) { nil }
  let(:options) do
    {
      translated_attribute_params: attribute_params,
      namespace: namespace,
      handle_duplicates: false
    }
  end
  let(:instance) { Post.new(id: id, title: 'T1', content: 'some content', published: true) }

  let(:locale) { nil }
  let(:value) { nil }
  let(:attribute) { nil }

  describe '#upload' do
    subject(:upload) { described_class.new(instance).upload(locale) }

    let(:worker_mock) { instance_double(I18nSonder::Workers::UploadSourceStringsWorker) }
    let(:locale) { :en }

    it "calls worker's perform synchronously with correct params" do
      allow(worker_class_mock).to receive(:perform_in)
      expect(I18nSonder::Workers::UploadSourceStringsWorker).to receive(:new).and_return(worker_mock)
      expect(worker_mock).to receive(:perform).with('Post', id, options).once
      upload
    end
  end

    describe '#upload_async' do
      subject(:upload) { described_class.new(instance).upload_async(locale) }

      it 'calls async worker with correct params and delay' do
      # worker will be called twice, once per translatable field
      expect(worker_class_mock).to(
          receive(:perform_in).with(5.minutes, 'Post', id, options).exactly(2).times
      )
      upload
    end

    context 'with non-default locale' do
      before do
        I18n.locale = :fr
        I18n.default_locale = :en
      end

      it 'does not upload for translation' do
        expect(worker_class_mock).not_to receive(:perform_in)
        upload
      end
    end

    context 'when instance id not present' do
      let(:instance) { Post.new(title: 'T1', content: 'some content', published: true) }

      it 'does not upload for translation' do
        expect(worker_class_mock).not_to receive(:perform_in)
        upload
      end
    end

    context 'for instance with allowed_for_translation? method' do
      context 'that evaluates to false' do
        before do
          class Post < ActiveRecord::Base
            def allowed_for_translation?; false; end
          end
        end

        let(:allowed) { false }
        it 'does not upload for translation' do
          expect(worker_class_mock).not_to receive(:perform_in)
          subject
        end
      end

      context 'that evaluates to true' do
        before do
          class Post < ActiveRecord::Base
            def allowed_for_translation?; true; end
          end
        end

        let(:allowed) { false }
        it 'uploads for translation' do
          expect(worker_class_mock).to(
              receive(:perform_in).with(5.minutes, 'Post', id, options).exactly(2).times
          )
          subject
        end
      end

      after do
        class Post < ActiveRecord::Base
          remove_method(:allowed_for_translation?)
        end
      end
    end

    context 'for instance with namespace_for_translation method' do
      let(:namespace) { ['dummy_namespace'] }
      before do
        class Post < ActiveRecord::Base
          def namespace_for_translation; ['dummy_namespace']; end
        end
      end

      it 'uploads for translation' do
        expect(worker_class_mock).to(
            receive(:perform_in).with(5.minutes, 'Post', id, options).exactly(2).times
        )
        upload
      end

      after do
        class Post < ActiveRecord::Base
          remove_method(:namespace_for_translation)
        end
      end
    end
  end
end
