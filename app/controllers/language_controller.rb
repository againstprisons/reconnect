class ReConnect::Controllers::LanguageController < ReConnect::Controllers::ApplicationController
  add_route :post, "/"

  def index
    lang = request.params['language']
    if lang.nil? || lang == ""
      lang = session[:lang] || ReConnect.default_language
    end

    lang = lang.to_s

    unless ReConnect.languages.key?(lang)
      flash :error, t(:'language/invalid')
      return redirect request.referer
    end

    session[:lang] = lang

    if logged_in?
      u = current_user
      u.encrypt(:preferred_language, lang)
      u.save
    end

    redirect request.referer
  end
end
