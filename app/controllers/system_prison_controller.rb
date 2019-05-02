class ReConnect::Controllers::SystemPrisonController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:prison:access")

    @title = t(:'system/prison/title')
    @prisons = ReConnect::Models::Prison.all.map do |p|
      {
        :id => p.id,
        :name => p.decrypt(:name),
      }
    end

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/prison/index', :layout => false, :locals => {
        :title => @title,
        :prisons => @prisons,
      })
    end
  end
end
