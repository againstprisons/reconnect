class ReConnect::Controllers::SystemGroupRemoveUserController < ReConnect::Controllers::ApplicationController
  add_route :get, '/'
  add_route :post, '/'

  def index(gid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:groups:modify")

    return redirect url("/system/group/#{@group.id}") if request.get?

    @group = ReConnect::Models::Group[gid.to_i]
    return halt 404 unless @group
    @usergroup = ReConnect::Models::UserGroup[request.params['ugid'].to_i]
    return halt 404 unless @usergroup

    user = @usergroup.user
    name = user.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    name = "(unknown)" if name.nil? || name&.strip&.empty?
    pseudonym = user.get_pseudonym

    @usergroup.delete

    flash :success, t(:'system/group/edit/members/item/remove/success', :name => name, :pseudonym => pseudonym)
    return redirect url("/system/group/#{@group.id}")
  end
end

