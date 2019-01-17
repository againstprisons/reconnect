class ReConnect::Controllers::AuthSignupController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return redirect "/" if logged_in?

    @title = t(:'auth/signup/title')

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title}) do
        haml(:'auth/signup', :locals => {
          :title => @title,
        })
      end
    end

    required = [
      !request.params["email"].nil?,
      request.params["email"] != "",
      !request.params["password"].nil?,
      request.params["password"] != "",
      !request.params["password_confirm"].nil?,
      request.params["password_confirm"] != "",
    ]

    unless required.all?
      flash :error, t(:required_field_missing)
      return redirect request.path
    end

    email = request.params["email"].strip.downcase
    password = request.params["password"]
    password_confirm = request.params["password_confirm"]

    # check if user exists with this email
    user_exists = ReConnect::Models::User.where(email: email).count.positive?
    if user_exists
      flash :error, t(:'auth/signup/email_already_used')
      return redirect request.path
    end

    # check password confirmation
    unless Rack::Utils.secure_compare(password, password_confirm)
      flash :error, t(:'auth/signup/password_confirm_incorrect')
      return redirect request.path
    end

    # if we get here, we can create the new user
    user = ReConnect::Models::User.new(email: email)
    user.password = password
    user.save

    token = user.login!
    session[:token] = token.token

    flash :success, t(:'auth/signup/success', :site_name => site_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect "/"
  end
end
