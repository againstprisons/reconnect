require 'rotp'
require 'rqrcode'

class ReConnect::Controllers::AccountMfaController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/disable", :method => :disable
  add_route :post, "/disable", :method => :disable

  def index
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user
    @title = t(:'account/mfa/title')
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?

    if !@totp_enabled
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/mfa/index_disabled', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    @has_roles = ReConnect::Models::UserRole.where(:user_id => @user.id).count.positive?
    @has_recovery = ReConnect::Models::Token.where(:user_id => @user.id, :use => 'twofactor_recovery').count.positive?

    haml(:'account/layout', :locals => {:title => @title}) do
      haml(:'account/mfa/index_enabled', :layout => false, :locals => {
        :title => @title,
        :has_roles => @has_roles,
        :totp_enabled => @totp_enabled,
        :security_keys => 0, # TODO: security keys
        :has_recovery => @has_recovery,
      })
    end
  end

  def disable
    unless logged_in?
      session[:after_login] = "/account/mfa"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user
    @title = t(:'account/mfa/remove/form/title')
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?
    @has_roles = ReConnect::Models::UserRole.where(:user_id => @user.id).count.positive?

    return redirect "/account/mfa" unless @totp_enabled
    if @has_roles
      flash :error, t(:'account/mfa/remove/cannot_disable_have_roles')
      return redirect "/account/mfa"
    end

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/mfa/disable', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    password = request.params["password"]&.strip
    unless @user.password_correct?(password)
      flash :error, t(:'account/mfa/remove/form/errors/invalid_password')
      return redirect request.path
    end

    # TODO: remove security keys once those are implemented
    @user.totp_enabled = false
    @user.totp_secret = nil
    @user.save

    flash :success, t(:'account/mfa/remove/form/success')
    return redirect "/account/mfa"
  end
end
