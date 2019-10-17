class ReConnect::Controllers::SystemGroupEditController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/settings", :method => :group_settings

  def index(gid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:group:access")

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
        :name => {
          :first => name.first || t(:'unknown'),
          :last => name.last || t(:'unknown'),
        },
        :pseudonym => user.get_pseudonym,
        :totp_enabled => user.totp_enabled && !(user.totp_secret.nil?),
        :added => ug.created,
        :link => url("/system/user/#{user.id}"),
      }
    end

    @roles = @group.group_roles.map do |gr|
      {
        :id => gr.id,
        :role => gr.role,
      }
    end

    @title = t(:'system/group/edit/title', :group_name => @group_name)

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/group/edit', :layout => false, :locals => {
        :title => @title,
        :group => {
          :id => @group.id,
          :name => @group_name,
          :requires_2fa => @group.requires_2fa,
          :created => @group.created,
          :members => @members,
          :roles => @roles,
        }
      })
    end
  end

  def group_settings(gid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:group:modify")

    @group = ReConnect::Models::Group[gid.to_i]
    return halt 404 unless @group
    @group_name = @group.decrypt(:name)

    new_name = request.params['name']&.strip
    if new_name.nil? || new_name&.empty?
      flash :error, t(:'system/group/edit/settings/errors/group_name_none')
      return redirect url("/system/group/#{@group.id}")
    end

    if new_name.strip != @group_name.strip
      @existing_group_names = ReConnect::Models::Group.all.map do |group|
        name = group.decrypt(:name).strip.downcase
        next nil if name == @group_name.strip.downcase
        name
      end.compact

      if @existing_group_names.include? new_name.strip.downcase
        flash :error, t(:'system/group/edit/settings/errors/group_name_conflict')
        return redirect url("/system/group/#{@group.id}")
      end

      @group.encrypt(:name, new_name)
    end

    if request.params['2fa']&.strip&.downcase == 'on'
      members_with_2fa = @group.user_groups.map do |ug|
        user = ug.user
        user.totp_enabled && !(user.totp_secret.nil?)
      end

      unless members_with_2fa.all?
        flash :error, t(:'system/group/edit/settings/errors/users_without_2fa')
        return redirect url("/system/group/#{@group.id}")
      end

      @group.requires_2fa = true
    else
      @group.requires_2fa = false
    end

    @group.save
    flash :success, t(:'system/group/edit/settings/success')
    return redirect url("/system/group/#{@group.id}")
  end
end

