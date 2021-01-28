require 'spec_helper'

RSpec.describe I18nSonder::TranslationsController, type: :controller do
  let(:worker) do
    class_double(I18nSonder::Workers::UpsertTranslationWorker)
      .as_stubbed_const(transfer_nested_constants: true)
  end

  context "#udpate" do
    let(:language) { "fr" }
    let(:translation_id) { "123" }
    let(:source_string_id) { "234" }
    let(:params) {
      {
        language: language,
        translation_id: translation_id,
        source_string_id: source_string_id
      }
    }

    it "calls UpsertTranslationWorker asnychronously" do
      expect(worker).to receive(:perform_async).with(language, translation_id, source_string_id)
      get :update, { use_route: :i18n_sonder }, params: params
    end
  end
end
