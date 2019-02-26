class ReConnect::Controllers::SystemUserRolesController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:roles")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user

    # TODO: Add checkbox-based role granting
    # This just redirects to the "advanced" role granting interface for now.

    redirect to("/system/user/#{@user.id}/roles/adv")
  end
end
