class ReConnect::Controllers::SystemUtilitiesController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:utilities:access")

    @title = t(:'system/utilities/title')
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/utilities/index', :layout => false, :locals => {
        :title => @title,
      })
    end
  end
end
