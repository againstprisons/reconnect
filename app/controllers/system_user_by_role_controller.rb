class ReConnect::Controllers::SystemUserByRoleController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemUserHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:roles")
    return redirect url("/system/user") if request.get?

    search = request.params['role']&.strip
    if search.nil? || search&.empty?
      flash :error, t(:'system/user/by_role/errors/no_role')
      return redirect url("/system/user")
    end

    dataset = ReConnect::Models::UserRole.where(:role => search)
    if search == '*'
      dataset = ReConnect::Models::UserRole.all
    end

    if dataset.count.zero?
      flash :error, t(:'system/user/by_role/errors/no_results')
      return redirect url("/system/user")
    end

    user_map = {}
    dataset.each do |ur|
      user_map[ur.user_id] ||= []
      user_map[ur.user_id] << {
        :id => ur.id,
        :ur => ur,
        :role => ur.role,
      }
    end

    @groups = ReConnect::Models::Group.all.map do |group|
      group.user_groups.each do |ug|
        user_map[ug.user_id] ||= []
      end

      data = {
        :group => group,
        :link => url("/system/group/#{group.id}"),
        :name => group.decrypt(:name),
        :roles => group.group_roles,
      }

      [group.id, data]
    end.to_h

    @users = user_map.map do |uid, user_roles|
      user = ReConnect::Models::User[uid]
      next nil unless user

      {
        :user => user,
        :link => url("/system/user/#{user.id}"),
        :name => user.get_name,
        :pseudonym => user.get_pseudonym,
        :user_roles => user.user_roles,
        :groups => user.user_groups.map(&:group_id),
      }
    end.compact

    @title = t(:'system/user/by_role/title')
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/user/by_role', :layout => false, :locals => {
        :title => @title,
        :users => @users,
        :groups => @groups,
      })
    end
  end
end
