class ReConnect::Controllers::SystemGroupDeleteController < ReConnect::Controllers::ApplicationController
  add_route :get, '/'
  add_route :post, '/'

  def index(gid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:groups:modify")

    @group = ReConnect::Models::Group[gid.to_i]
    return halt 404 unless @group
    @group_name = @group.decrypt(:name)

    @members = @group.user_groups.map do |ug|
      user = ug.user
      name = user.get_name

      {
        :ids => {
          :user => user.id,
          :ug => ug.id,
        },
        :objs => {
          :user => user,
          :ug => ug,
        },
        :name => {
          :first => name.first || t(:'unknown'),
          :last => name.last || t(:'unknown'),
        },
        :pseudonym => user.get_pseudonym,
        :totp_enabled => user.totp_enabled && !(user.totp_secret.nil?),
        :link => url("/system/user/#{user.id}"),
      }
    end

    @roles = @group.group_roles.map do |gr|
      {
        :id => gr.id,
        :role => gr.role,
        :obj => gr,
      }
    end

    @title = t(:'system/group/delete/title', :group_name => @group_name)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/group/delete', :layout => false, :locals => {
          :title => @title,
          :group => {
            :id => @group.id,
            :name => @group_name,
            :members => @members,
            :roles => @roles,
          }
        })
      end
    end

    unless request.params['name']&.strip == @group_name.strip
      flash :error, t(:'system/group/delete/errors/failed_confirm')
      return redirect request.path
    end

    @roles.each do |r|
      r[:obj].delete
    end

    @members.each do |m|
      m[:objs][:ug].delete
    end

    @group.delete

    flash :success, t(:'system/group/delete/success', :name => @group_name)
    return redirect url("/system/group")
  end
end


