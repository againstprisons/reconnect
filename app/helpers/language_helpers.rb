module ReConnect::Helpers::LanguageHelpers
  def current_language
    return session[:lang] if session.key?(:lang)
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

    erb = ERB.new(text)

    data = OpenStruct.new
    values.keys.each do |key|
      data.send("#{key}=".to_sym, values[key])
    end

    b = data.instance_eval do
      binding
    end

    erb.result(b)
  end
end
