class ReConnect::Controllers::SystemGroupRolesController < ReConnect::Controllers::ApplicationController
  add_route :get, '/add'
  add_route :post, '/add'
  add_route :get, '/delete', :method => :delrole
  add_route :post, '/delete', :method => :delrole

  def index(gid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:group:role_modify")

    @group = ReConnect::Models::Group[gid.to_i]
    return halt 404 unless @group
    @group_name = @group.decrypt(:name)
    return halt 418 unless @group.requires_2fa

    @roles = @group.group_roles.map do |gr|
      {
        :id => gr.id,
        :role => gr.role,
      }
    end

    @title = t(:'system/group/edit/title', :group_name => @group_name)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/group/addrole', :layout => false, :locals => {
          :title => @title,
          :group => {
            :id => @group.id,
            :name => @group_name,
            :roles => @roles,
          }
        })
      end
    end

    role = request.params['role']&.strip&.downcase
    if role.nil? || role&.empty?
      flash :error, t(:'system/group/edit/roles/add/errors/no_role')
      return redirect request.path
    end

    if @roles.map{|x| x[:role]}.include? role
      flash :error, t(:'system/group/edit/roles/add/errors/already_exists')
      return redirect request.path
    end

    gr = ReConnect::Models::GroupRole.new(:group_id => @group.id, :role => role)
    gr.save

    flash :success, t(:'system/group/edit/roles/add/success', :id => gr.id)
    return redirect url("/system/group/#{@group.id}")
  end

  def delrole(gid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:group:role_modify")

    return redirect url("/system/group/#{@group.id}") if request.get?

    @group = ReConnect::Models::Group[gid.to_i]
    return halt 404 unless @group
    @grouprole = ReConnect::Models::GroupRole[request.params['grid'].to_i]
    return halt 404 unless @grouprole

    role = @grouprole.role.dup
    @grouprole.delete

    flash :success, t(:'system/group/edit/roles/remove/success', :role => role)
    return redirect url("/system/group/#{@group.id}")
  end
end
