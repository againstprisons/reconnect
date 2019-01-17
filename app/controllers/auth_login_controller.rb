class ReConnect::Controllers::AuthLoginController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return redirect "/" if logged_in?

    @title = t(:'auth/login/title')

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title}) do
        haml(:'auth/login', :locals => {
          :title => @title,
        })
      end
    end

    required = [
      !request.params["email"].nil?,
      request.params["email"] != "",
      !request.params["password"].nil?,
      request.params["password"] != "",
    ]

    unless required.all?
      flash :error, t(:required_field_missing)
      return redirect request.path
    end

    email = request.params["email"].strip.downcase
    password = request.params["password"]

    # check if user exists with this email
    user = ReConnect::Models::User.where(email: email).first
    unless user
      flash :error, t(:'auth/login/failure')
      return redirect request.path
    end

    # check password confirmation
    unless user.password_correct?(password)
      flash :error, t(:'auth/login/failure')
      return redirect request.path
    end

    # if we get here, user has successfully logged in
    token = user.login!
    session[:token] = token.token

    if user.preferred_language
      lang = user.decrypt(:preferred_language)
      session[:lang] = lang
    end

    flash :success, t(:'auth/login/success', :site_name => site_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect "/"
  end
end
