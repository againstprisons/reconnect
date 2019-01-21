class ReConnect::Controllers::AccountIndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/edit-name", :method => :edit_name
  add_route :post, "/edit-email", :method => :edit_email
  add_route :post, "/edit-password", :method => :edit_password

  def index
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @title = t(:'account/title')

    haml(:'account/layout', :locals => {:title => @title}) do
      haml(:'account/index', :layout => false, :locals => {
        :title => @title
      })
    end
  end

  def edit_name
    unless logged_in?
      session[:after_login] = "/account"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    new_name = request.params["name"]
    if new_name.nil? || new_name == ""
      flash :error, t(:'required_field_missing')
      return redirect to("/account")
    end

    user = current_user
    user.encrypt(:name, new_name.strip)
    user.save

    flash :success, t(:'account/change_name/success')

    return redirect to("/account")
  end

  def edit_email
    unless logged_in?
      session[:after_login] = "/account"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    user = current_user

    # verify password
    password = request.params["password"]
    if password.nil? || !user.password_correct?(password)
      flash :error, t(:'account/change_email/password_incorrect')
      return redirect to("/account")
    end

    # validate email
    email = request.params["email"]&.strip&.downcase
    if email.nil? || email == ""
      flash :error, t(:'required_field_missing')
      return redirect to("/account")
    end

    # check the user isn't trying to change their email to their current email
    if user.email == email
      flash :error, t(:'account/change_email/change_to_current')
      return redirect to("/account")
    end

    # check no user already exists with this email address
    if ReConnect::Models::User.where(:email => email).count.positive?
      flash :error, t(:'account/change_email/email_already_used')
      return redirect to("/account")
    end

    # save new email
    user.email = email
    user.save

    flash :success, t(:'account/change_email/success')
    return redirect to("/account")
  end

  def edit_password
    unless logged_in?
      session[:after_login] = "/account"
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    user = current_user

    # verify password
    password = request.params["password"]
    if password.nil? || !user.password_correct?(password)
      flash :error, t(:'account/change_email/password_incorrect')
      return redirect to("/account")
    end

    # get new password
    newpass = request.params["new_password"]
    newpass_confirm = request.params["new_password_confirm"]
    if newpass.nil? || newpass&.strip == "" || newpass_confirm.nil? || newpass_confirm&.strip == ""
      flash :error, t(:'required_field_missing')
      return redirect to("/account")
    end

    unless newpass == newpass_confirm
      flash :error, t(:'account/change_password/does_not_match')
      return redirect to("/account")
    end

    user.password = newpass
    user.invalidate_all_tokens_except!(current_token)
    user.save

    flash :success, t(:'account/change_password/success')

    return redirect to("/account")
  end
end
