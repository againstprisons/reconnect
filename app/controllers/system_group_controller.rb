class ReConnect::Controllers::SystemGroupController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:group:access")

    @title = t(:'system/group/title')
    @groups = ReConnect::Models::Group.all.map do |group|
      {
        :id => group.id,
        :link => url("/system/group/#{group.id}"),
        :name => group.decrypt(:name),
        :requires_2fa => group.requires_2fa,
        :user_count => ReConnect::Models::UserGroup.where(:group_id => group.id).count,
      }
    end

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/group/index', :layout => false, :locals => {
        :title => @title,
        :groups => @groups,
      })
    end
  end
end
