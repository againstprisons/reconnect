class ReConnect::Controllers::AuthLoginTotpController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return redirect "/" if logged_in?

    uid = session[:twofactor_uid]
    return redirect to("/auth") unless uid

    user = ReConnect::Models::User[uid]
    return redirect to("/auth") unless user
    return redirect to("/auth") unless user.totp_enabled
    return redirect to("/auth") if user.totp_secret.nil? || user.totp_secret&.empty?

    @title = t(:'auth/login/mfa/title')

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title, :auth_no_tabs => true}) do
        haml(:'auth/login/mfa/totp', :layout => false, :locals => {
          :title => @title,
          :has_security_key => false, # TODO: security key support
        })
      end
    end

    code = request.params["code"]&.strip&.downcase
    code = code.split(" ").map{|x| x.split('-')}.flatten.join

    # check for recovery code
    is_recovery = false
    if code.length > 8
      token = ReConnect::Models::Token.where(:user_id => user.id, :token => code, :use => "twofactor_recovery").first
      if token.nil? || !(token.check_validity!())
        # invalid code
        flash :error, t(:'auth/login/mfa/totp/errors/invalid_code')
        return redirect request.path
      end

      is_recovery = true
    else
      rotp = ROTP::TOTP.new(user.decrypt(:totp_secret), :issuer => site_name.gsub(":", "_"))
      if rotp.verify(code, drift_behind: 15).nil?
        # invalid code
        flash :error, t(:'auth/login/mfa/totp/errors/invalid_code')
        return redirect request.path
      end
    end

    # if we get here, user has successfully logged in
    session.delete(:twofactor_uid)
    token = user.login!
    session[:token] = token.token
    token.update(extra_data: JSON.generate({
      ip_address: request.ip,
      user_agent: request.user_agent,
    }))

    if user.preferred_language
      lang = user.decrypt(:preferred_language)
      session[:lang] = lang
    end

    # redirect away to MFA settings if recovery code was used
    if is_recovery
      flash :success, t(:'auth/login/mfa/recovery/success', :site_name => site_name)
      return redirect to("/account/mfa")
    end

    flash :success, t(:'auth/login/success', :site_name => site_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect to("/")
  end
end
