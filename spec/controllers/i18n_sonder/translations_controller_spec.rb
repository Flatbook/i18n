require 'spec_helper'

RSpec.describe I18nSonder::TranslationsController, type: :controller do
  routes { I18nSonder::Engine.routes }

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
        translation: {
          language: language,
          translation_id: translation_id,
          source_string_id: source_string_id
        }
      }
    }
    let(:expected_auth_token) { "dummy_auth" }

    before do
      allow(I18nSonder.configuration).to receive(:auth_token).and_return(expected_auth_token)
      request.headers["Authorization"] = auth_token
    end

    context "with valid auth token" do
      let(:auth_token) { expected_auth_token }

      it "calls UpsertTranslationWorker asnychronously" do
        expect(worker).to receive(:perform_async).with(language, translation_id, source_string_id)
        post :update, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid auth token" do
      let(:auth_token) { "bad_token" }

      it "returns 403 error" do
        expect(worker).not_to receive(:perform_async).with(language, translation_id, source_string_id)
        post :update, params: params
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
