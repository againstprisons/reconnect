class ReConnect::Controllers::SystemPenpalViewController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[uid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name
    @user = @penpal.user

    @display_fields = [
      [t(:'penpal_id'), @penpal.id.inspect],
      [t(:'name'), @name],
    ]

    @title = t(:'system/penpal/view/title', :name => @name, :id => @penpal.id)
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/view', :layout => false, :locals => {
        :title => @title,
        :penpal => @penpal,
        :user => @user,
        :display_fields => @display_fields,
      })
    end
  end
end
