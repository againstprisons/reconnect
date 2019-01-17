class ReConnect::Controllers::AccountIndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect "/auth"
    end

    @title = t(:'account/title')

    if request.get?
      return haml(:'account/layout', :locals => {:title => @title}) do
        haml(:'account/index', :locals => {
          :title => @title
        })
      end
    end
  end
end
