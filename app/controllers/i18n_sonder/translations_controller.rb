class I18nSonder::TranslationsController < ActionController::Base
  before_action :authenticate

  def update
    I18nSonder::Workers::UpsertTranslationWorker.perform_async(
      language, translation_id, source_string_id
    )

    head :ok
  end

  private

  def translation_params
    @translation_params ||= params.require(:translation)
      .permit(:language, :translation_id, :source_string_id)
  end

  def language
    translation_params[:language]
  end

  def translation_id
    translation_params[:translation_id]
  end

  def source_string_id
    translation_params[:source_string_id]
  end

  def authenticate
    return if Rails.env.development?

    if request.headers["Authorization"].present?
      token = request.headers["Authorization"].split(" ").last
      return if token == I18nSonder.configuration.auth_token
    end

    head :forbidden
  end
end
