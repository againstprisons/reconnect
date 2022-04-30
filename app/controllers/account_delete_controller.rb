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

    # Generate a verification code and store it in the session if one
    # doesn't already exist there
    if session.key?(:account_delete_verifycode)
      @verify_code = session[:account_delete_verifycode]
    else
      @verify_code = Random.new.rand(100000000 .. 999999999).to_s
      session[:account_delete_verifycode] = @verify_code
    end

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/delete', :layout => false, :locals => {
          :title => @title,
          :user => @user,
          :verify_code => @verify_code,
        })
      end
    end

    # Check verification code
    form_verify = request.params['verify']&.strip
    form_verify = form_verify&.split(' ')&.map{|x| x.split('-')}&.flatten&.join('')
    if form_verify != session.delete(:account_delete_verifycode)
      flash :error, t(:'account/delete/errors/invalid_code')
      return redirect request.path
    end

    # Check password
    password = request.params["password"]&.strip
    if password.nil? || password&.empty?
      flash :error, t(:'account/delete/errors/invalid_password')
      return redirect request.path
    else
      unless @user.password_correct?(password)
        flash :error, t(:'account/delete/errors/invalid_password')
        return redirect request.path
      end
    end

    # Mark account for soft deletion
    @user.soft_delete!

    # Invalidate and remove session token
    @user.invalidate_tokens!
    session.delete(:token)

    # Redirect to index
    flash :success, t(:'account/delete/success')
    redirect to("/")
  end
end
