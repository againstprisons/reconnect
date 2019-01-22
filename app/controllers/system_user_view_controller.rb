class ReConnect::Controllers::SystemUserViewController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @name = @user.decrypt(:name)

    @title = t(:'system/user/view/title', :name => @name, :id => @user.id)

    display_fields = [
      [t(:'name'), @name],
      [t(:'email_address'), @user.email],
      [t(:'user_id'), @user.id],
      [t(:'system/user/view/penpal_id'), @user.penpal&.id.inspect],
      [t(:'system/user/view/current_sessions'), @user.tokens.select{|x| x.use == "session" && x.valid}.count],
      [t(:'system/user/view/roles'), @user.user_roles.count],
    ]

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/user/view', :layout => false, :locals => {
        :title => @title,
        :user => @user,
        :penpal_obj => @user.penpal,
        :display_fields => display_fields,
      })
    end
  end
end
