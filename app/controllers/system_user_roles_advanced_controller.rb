class ReConnect::Controllers::SystemUserRolesAdvancedController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/remove/:role_id", :method => :remove
  add_route :post, "/remove/:role_id", :method => :remove
  add_route :get, "/add", :method => :add
  add_route :post, "/add", :method => :add

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:roles")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @name = @user.decrypt(:name)
    @email = @user.email
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?
    @roles = ReConnect::Models::UserRole.where(:user_id => @user.id).all.map do |r|
      {
        :user_role_id => r.id,
        :role => r.role,
      }
    end

    @title = t(:'system/user/roles/advanced/title', :name => @name, :id => @user.id)

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/user/roles/advanced', :layout => false, :locals => {
        :title => @title,
        :user => @user,
        :user_name => @name,
        :user_email => @email,
        :user_totp_enabled => @totp_enabled,
        :user_roles => @roles,
      })
    end
  end

  def remove(uid, role_id)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:roles")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @name = @user.decrypt(:name)

    @role = ReConnect::Models::UserRole[role_id.to_i]
    return halt 404 unless @role

    @title = t(:'system/user/roles/advanced/remove_role/title')

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/user/roles/advanced_remove', :layout => false, :locals => {
          :title => @title,
          :user => @user,
          :user_name => @name,
          :role => @role,
        })
      end
    end

    unless request.params["do_remove"]&.strip&.to_i == 1
      return redirect request.path
    end

    @role_id = @role.id
    @role_desc = @role.role
    @role.delete

    flash :success, t(:'system/user/roles/advanced/remove_role/success', {
      :role => @role_desc,
      :role_id => @role_id,
      :user_name => @name,
      :user_id => @user.id,
    })

    return redirect to("/system/user/#{@user.id}/roles/adv")
  end

  def add(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:roles")
    return redirect to("/system/user/#{uid}/roles/adv") if request.get?

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @name = @user.decrypt(:name)

    # enforce 2fa
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?
    unless @totp_enabled
      flash :error, t(:'system/user/roles/advanced/add_role/no_twofactor')
      return redirect to("/system/user/#{@user.id}/roles/adv")
    end

    # validity checking on role
    role = request.params["role"]&.strip&.downcase
    if role.nil? || role.empty?
      flash :error, t(:'system/user/roles/advanced/add_role/no_role_provided')
      return redirect to("/system/user/#{@user.id}/roles/adv")
    end

    # error if role already exists
    if ReConnect::Models::UserRole.where(:user_id => @user.id, :role => role).count.positive?
      flash :error, t(:'system/user/roles/advanced/add_role/role_exists')
      return redirect to("/system/user/#{@user.id}/roles/adv")
    end

    # save new role
    @role = ReConnect::Models::UserRole.new(:user_id => @user.id, :role => role)
    @role.save

    flash :success, t(:'system/user/roles/advanced/add_role/success', {
      :role => @role.role,
      :role_id => @role.id,
      :user_name => @name,
      :user_id => @user.id,
    })

    return redirect to("/system/user/#{@user.id}/roles/adv")
  end
end
