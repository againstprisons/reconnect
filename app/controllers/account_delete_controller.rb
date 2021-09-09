class ReConnect::Controllers::AccountDeleteController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user
    @title = t(:'account/delete/title')

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/delete', :layout => false, :locals => {
          :title => @title,
          :user => @user,
        })
      end
    end

    password = request.params["password"]&.strip
    if password.nil? || password&.empty?
      flash :error, t(:'account/delete/errors/invalid_password')
      return redirect request.path
    end

    unless @user.password_correct?(password)
      flash :error, t(:'account/delete/errors/invalid_password')
      return redirect request.path
    end

    # Mark account for soft deletion
    @user.soft_delete!

    # Invalidate and remove session token
    current_token.invalidate!
    session.delete(:token)

    # Redirect to index
    flash :success, t(:'account/delete/success')
    redirect to("/")
  end
end
