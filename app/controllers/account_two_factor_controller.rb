class ReConnect::Controllers::AccountTwoFactorController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @title = t(:'account/twofactor')

    haml(:'account/layout', :locals => {:title => @title}) do
      haml(:'account/twofactor/index', :layout => false, :locals => {
        :title => @title
      })
    end
  end
end
