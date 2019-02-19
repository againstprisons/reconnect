require 'rotp'
require 'rqrcode'

class ReConnect::Controllers::AccountTwoFactorController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/totp", :method => :totp
  add_route :post, "/totp", :method => :totp
  add_route :get, "/disable", :method => :disable
  add_route :post, "/disable", :method => :disable
  add_route :get, "/recovery", :method => :recovery
  add_route :post, "/recovery/regen", :method => :recovery_regen

  def index
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user
    @title = t(:'account/twofactor')
    @has_roles = ReConnect::Models::UserRole.where(:user_id => @user.id).count.positive?
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?

    haml(:'account/layout', :locals => {:title => @title}) do
      haml(:'account/twofactor/index', :layout => false, :locals => {
        :title => @title,
        :has_roles => @has_roles,
        :totp_enabled => @totp_enabled,
      })
    end
  end

  def totp
    unless logged_in?
      session[:after_login] = "/account/twofactor"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user
    @title = t(:'account/twofactor/totp/setup/title')

    # get TOTP secret for setup from session, generating a new secret if
    # there's not one on the session
    @secret = session.delete(:totp_secret)
    @secret = ROTP::Base32.random_base32 unless @secret
    session[:totp_secret] = @secret

    # create TOTP instance
    rotp = ROTP::TOTP.new(@secret, :issuer => site_name.gsub(":", "_"))

    # generate provisioning URI
    uri = rotp.provisioning_uri(@user.email)

    # generate QR code
    qr = RQRCode::QRCode.new(uri)
    svg = qr.as_svg(:offset => 0, :color => '000', :shape_rendering => 'crispEdges', :module_size => 5)
    @svg = "data:image/svg+xml;base64,#{Base64.encode64(svg)}"

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/twofactor/totp', :layout => false, :locals => {
          :title => @title,
          :secret => @secret,
          :svg => @svg,
        })
      end
    end

    # verify code
    code = request.params["code"]&.strip&.downcase
    if rotp.verify(code, drift_behind: 15).nil?
      # invalid
      flash :error, t(:'account/twofactor/totp/setup/invalid_code')
      return redirect request.path
    end

    # delete from session
    session.delete(:totp_secret)

    # code valid, store secret
    @user.encrypt(:totp_secret, @secret)
    @user.totp_enabled = true
    @user.save

    flash :success, t(:'account/twofactor/totp/setup/success')
    return redirect to('/account/twofactor')
  end

  def disable
    unless logged_in?
      session[:after_login] = "/account/twofactor"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user
    @title = t(:'account/twofactor/remove/form/title')
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?
    @has_roles = ReConnect::Models::UserRole.where(:user_id => @user.id).count.positive?

    return redirect "/account/twofactor" unless @totp_enabled
    if @has_roles
      flash :error, t(:'account/twofactor/remove/cannot_disable_have_roles')
      return redirect "/account/twofactor"
    end

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/twofactor/disable', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    unless request.params["confirm"]&.strip&.downcase == "on"
      flash :error, t(:'account/twofactor/remove/form/confirm_not_checked')
      return redirect request.path
    end

    # TODO: remove U2F once that's implemented
    @user.totp_enabled = false
    @user.totp_secret = nil
    @user.save

    flash :success, t(:'account/twofactor/remove/form/success')
    return redirect "/account/twofactor"
  end

  def recovery
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @title = t(:'account/twofactor/recovery/view/title')
    @user = current_user
    @codes = ReConnect::Models::Token.where(:user_id => @user.id, :use => 'twofactor_recovery', :valid => true).map do |t|
      t.token.split("").each_slice(4).map(&:join).join(" ")
    end

    if request.params["dl"]&.strip&.downcase.to_i == 1
      output = [
        "Two-factor authentication recovery codes for: #{@user.email}",
        80.times.map{"="}.join(),
        @codes.map{|x| "- #{x}"}
      ].flatten.join("\n")

      content_type "text/plain"
      attachment "recovery_codes.txt"
      return output
    end

    haml(:'account/layout', :locals => {:title => @title}) do
      haml(:'account/twofactor/recovery', :layout => false, :locals => {
        :title => @title,
        :codes => @codes,
      })
    end
  end

  def recovery_regen
    unless logged_in?
      session[:after_login] = "/account/twofactor/recovery"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user

    # delete existing codes
    ReConnect::Models::Token.where(:user_id => @user.id, :use => 'twofactor_recovery', :valid => true).delete

    # generate new codes
    10.times.each do 
      token = ReConnect::Models::Token.generate
      token.user_id = @user.id
      token.use = "twofactor_recovery"
      token.token = token.token[0..11]
      token.save
    end

    flash :success, t(:'account/twofactor/recovery/regen/success')
    return redirect "/account/twofactor/recovery"
  end
end
