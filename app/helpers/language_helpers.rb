require 'erb'

module ReConnect::Helpers::LanguageHelpers
  # This class exists to let translated text call t()
  class LanguageData < OpenStruct
    include ReConnect::Helpers::LanguageHelpers

    def e(text)
      ERB::Util.html_escape(text)
    end

    def site_name
      ReConnect.app_config['site-name']
    end

    def org_name
      ReConnect.app_config['org-name']
    end
  end

  def languages
    ReConnect.languages
  end

  def current_language
    if defined?(session) && session.key?(:lang)
      return session[:lang]
    end

    ReConnect.default_language
  end

  def t(translation_key, values = {})
    language = current_language
    language = values.delete(:force_language) if values[:force_language]
    return translation_key.to_s if language == "translationkeys"

    text = ReConnect.languages[language]&.fetch(translation_key, nil)
    text = ReConnect.languages[ReConnect.default_language].fetch(translation_key, nil) unless text

    unless text
      return "##MISSING(#{translation_key.to_s})##"
    end

    values = LanguageData.new(values)
    template = Tilt::ERBTemplate.new() { text }
    template.render(values)
  end
end
