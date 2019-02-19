class ReConnect::Controllers::AuthLoginController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"
  add_route :get, "/twofactor", :method => :twofactor
  add_route :post, "/twofactor", :method => :twofactor

  def index
    return redirect "/" if logged_in?

    @title = t(:'auth/login/title')

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title}) do
        haml(:'auth/login/index', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    errs = [
      request.params["email"].nil?,
      request.params["email"]&.strip.empty?,
      request.params["password"].nil?,
      request.params["password"].empty?,
    ]

    if errs.any?
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

    if user.totp_enabled
      session[:twofactor_uid] = user.id
      return redirect to("/auth/twofactor")
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
    redirect to("/")
  end

  def twofactor
    return redirect "/" if logged_in?

    uid = session[:twofactor_uid]
    return redirect to("/auth") unless uid

    user = ReConnect::Models::User[uid]
    return redirect to("/auth") unless user
    return redirect to("/auth") unless user.totp_enabled
    return redirect to("/auth") if user.totp_secret.nil?

    @title = t(:'auth/login/twofactor/title')

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title, :auth_no_tabs => true}) do
        haml(:'auth/login/twofactor', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    rotp = ROTP::TOTP.new(user.decrypt(:totp_secret), :issuer => site_name.gsub(":", "_"))
    totp_code = request.params["totp_code"]&.strip&.downcase
    if rotp.verify(totp_code, drift_behind: 15).nil?
      # invalid totp code
      flash :error, t(:'auth/login/twofactor/invalid_code')
      return redirect request.path
    end

    # if we get here, user has successfully logged in
    session.delete(:twofactor_uid)
    token = user.login!
    session[:token] = token.token

    if user.preferred_language
      lang = user.decrypt(:preferred_language)
      session[:lang] = lang
    end

    flash :success, t(:'auth/login/success', :site_name => site_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect to("/")
  end
end
