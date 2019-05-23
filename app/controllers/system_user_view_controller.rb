class ReConnect::Controllers::SystemUserViewController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemUserHelpers

  add_route :get, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @user_d = user_view_data(@user)
    @penpal = ReConnect::Models::Penpal[@user.penpal_id]

    @title = t(:'system/user/view/title', :name => @user_d[:name], :id => @user.id)

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/user/view', :layout => false, :locals => {
        :title => @title,
        :user => @user,
        :penpal_obj => @penpal,
        :display_fields => @user_d[:display_fields],
      })
    end
  end
end
