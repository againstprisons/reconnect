class ReConnect::Controllers::SystemIndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:access")

    @title = t(:'system/title')

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/index', :layout => false, :locals => {
        :title => @title
      })
    end
  end
end
