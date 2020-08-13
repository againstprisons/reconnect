class ReConnect::Controllers::AccountMfaRecoveryController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    unless logged_in?
      session[:after_login] = "/account/mfa/recovery"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @title = t(:'account/mfa/recovery/splash/title')
    @user = current_user
    @has_codes = ReConnect::Models::Token.where(:user_id => @user.id, :use => 'twofactor_recovery').count.positive?

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/mfa/recovery', :layout => false, :locals => {
          :title => @title,
          :has_codes => @has_codes,
        })
      end
    end

    # delete existing codes
    ReConnect::Models::Token.where(:user_id => @user.id, :use => 'twofactor_recovery', :valid => true).delete

    # generate new codes
    @codes = 10.times.map do
      token = ReConnect::Models::Token.generate_short
      token.user_id = @user.id
      token.use = "twofactor_recovery"
      token.save

      token.token.split("").each_slice(4).map(&:join).join(" ")
    end

    @title = t(:'account/mfa/recovery/view/title')
    haml(:'account/layout', :locals => {:title => @title}) do
      haml(:'account/mfa/recovery_view', :layout => false, :locals => {
        :title => @title,
        :codes => @codes,
      })
    end
  end
end