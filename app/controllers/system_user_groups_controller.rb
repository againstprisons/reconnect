class ReConnect::Controllers::SystemUserGroupsController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemUserHelpers

  add_route :get, "/"
  add_route :post, "/add", :method => :add
  add_route :post, "/remove", :method => :remove

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:groups:access")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @user_d = user_view_data(@user)
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?

    @assigned_groups = @user_d[:groups].sort{|a, b| a[:ids][:group] <=> b[:ids][:group]}
    @available_groups = ReConnect::Models::Group.all.map do |group|
      next nil if @assigned_groups.map{|x| x[:ids][:group]}.include? group.id

      {
        :id => group.id,
        :name => group.decrypt(:name),
        :requires_2fa => group.requires_2fa,
      }
    end.compact.sort{|a, b| a[:id] <=> b[:id]}

    @title = t(:'system/user/groups/title', :name => @user_d[:name], :pseudonym => @user_d[:pseudonym], :id => @user.id)

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/user/groups', :layout => false, :locals => {
        :title => @title,
        :user => @user,
        :user_d => @user_d,
        :totp_enabled => @totp_enabled,
        :groups => {
          :assigned => @assigned_groups,
          :available => @available_groups,
        }
      })
    end
  end

  def add(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:groups:modify")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @user_d = user_view_data(@user)
    @totp_enabled = @user.totp_enabled && !@user.totp_secret.nil?

    @group = ReConnect::Models::Group[request.params['group'].to_i]
    return halt 404 unless @group
    @group_name = @group.decrypt(:name)

    if @user_d[:groups].map{|x| x[:ids][:group]}.include? @group.id
      flash :error, t(:'system/user/groups/available/errors/already_in_group', :group_name => @group_name)
      return redirect url("/system/user/#{@user.id}/groups")
    end

    if @group.requires_2fa && !totp_enabled
      flash :error, t(:'system/user/groups/available/errors/no_twofactor', :group_name => @group_name)
      return redirect url("/system/user/#{@user.id}/groups")
    end

    ug = ReConnect::Models::UserGroup.new(:user_id => @user.id, :group_id => @group.id)
    ug.save

    flash :success, t(:'system/user/groups/available/success', :group_name => @group_name)
    return redirect url("/system/user/#{@user.id}/groups")
  end

  def remove(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:groups:modify")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @user_d = user_view_data(@user)

    @ug = ReConnect::Models::UserGroup[request.params['ugid'].to_i]
    return halt 404 unless @ug
    @group = @ug.group
    return halt 404 unless @group
    @group_name = @group.decrypt(:name)

    unless @user_d[:groups].map{|x| x[:ids][:group]}.include? @group.id
      flash :error, t(:'system/user/groups/assigned/errors/not_in_group', :group_name => @group_name)
      return redirect url("/system/user/#{@user.id}/groups")
    end

    @ug.delete

    flash :success, t(:'system/user/groups/assigned/success', :group_name => @group_name)
    return redirect url("/system/user/#{@user.id}/groups")
  end

end
