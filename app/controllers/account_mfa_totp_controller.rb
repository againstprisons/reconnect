require 'rotp'
require 'rqrcode'

class ReConnect::Controllers::AccountMfaTotpController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    unless logged_in?
      session[:after_login] = "/account/mfa"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user
    @title = t(:'account/mfa/totp/setup/title')

    # get TOTP secret for setup from session, generating a new secret if
    # there's not one on the session
    @secret = session.delete(:totp_secret)
    @secret = ROTP::Base32.random_base32 unless @secret
    session[:totp_secret] = @secret

    # create TOTP instance
    rotp = ROTP::TOTP.new(@secret, :issuer => site_name.gsub(":", "_"))

    # generate provisioning URI
    @uri = rotp.provisioning_uri(@user.email)

    # generate QR code
    qr = RQRCode::QRCode.new(@uri)
    svg = qr.as_svg(:offset => 0, :color => '000', :shape_rendering => 'crispEdges', :module_size => 5)
    @svg = "data:image/svg+xml;base64,#{Base64.encode64(svg)}"

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/mfa/totp', :layout => false, :locals => {
          :title => @title,
          :secret => @secret,
          :svg => @svg,
          :uri => @uri,
        })
      end
    end

    # verify code
    code = request.params["code"]&.strip&.downcase
    if rotp.verify(code, drift_behind: 15).nil?
      # invalid
      flash :error, t(:'account/mfa/totp/setup/invalid_code')
      return redirect request.path
    end

    # code valid, store secret
    @user.encrypt(:totp_secret, @secret)
    @user.totp_enabled = true
    @user.save

    # delete from session
    session.delete(:totp_secret)

    flash :success, t(:'account/mfa/totp/setup/success')
    return redirect to('/account/mfa')
  end
end
