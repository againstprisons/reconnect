module ReConnect::Helpers::LanguageHelpers
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

    if language == "translationkeys"
      return translation_key.to_s
    end

    default_lang_entry = ReConnect.languages[ReConnect.default_language]
    lang_entry = ReConnect.languages[language]
    lang_entry = default_lang_entry unless lang_entry

    text = lang_entry[translation_key] if lang_entry
    text = default_lang_entry[translation_key] if !text && default_lang_entry
    return "##MISSING(#{translation_key.to_s})##" unless text

    values.merge!({
      :site_name => ReConnect.app_config['site-name'],
      :org_name => ReConnect.app_config['org-name'],
    })

    values = OpenStruct.new(values)
    template = Tilt::ERBTemplate.new() { text }
    template.render(values)
  end
end
