class ReConnect::Controllers::AuthPasswordResetController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"
  add_route :get, "/:token", :method => :reset
  add_route :post, "/:token", :method => :reset

  def index
    return redirect "/" if logged_in?

    @title = t(:'auth/reset/title')

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title}) do
        haml(:'auth/reset/index', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    email = request.params["email"]&.strip&.downcase
    @user = ReConnect::Models::User.where(:email => email).first

    @user.password_reset! if @user

    haml(:'auth/layout', :locals => {:title => @title}) do
      haml(:'auth/reset/sent', :layout => false, :locals => {
        :title => @title,
      })
    end
  end

  def reset(token)
    return redirect "/" if logged_in?

    @title = t(:'auth/reset/title')

    @token = ReConnect::Models::Token.where(:token => token).first
    return halt 404 unless @token

    # check validity and expiry
    unless @token.check_validity!
      # return a page saying the token has expired if that's what has happened
      if @token.expiry && Time.now >= @token.expiry
        return haml(:'auth/layout', :locals => {:title => @title, :auth_no_tabs => true}) do
          haml(:'auth/reset/expired', :layout => false, :locals => {
            :title => @title,
          })
        end
      end

      return halt 404
    end

    @user = ReConnect::Models::User[@token.user_id]
    return halt 404 unless @user

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title, :auth_no_tabs => true}) do
        haml(:'auth/reset/new_pass', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    required = [
      !request.params["password"].nil?,
      request.params["password"] != "",
      !request.params["password_confirm"].nil?,
      request.params["password_confirm"] != "",
    ]

    unless required.all?
      flash :error, t(:required_field_missing)
      return redirect request.path
    end

    password = request.params["password"]
    password_confirm = request.params["password_confirm"]

    # check password confirmation
    unless Rack::Utils.secure_compare(password, password_confirm)
      flash :error, t(:'auth/reset/password_confirm_incorrect')
      return redirect request.path
    end

    # change password
    @token.invalidate!
    @user.password = password
    @user.save

    flash :success, t(:'auth/reset/success')
    return redirect to("/auth")
  end
end
