class ReConnect::Controllers::SystemUserPenpalObjectController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user

    @penpal = @user.penpal
    unless @penpal
      @penpal = ReConnect::Models::Penpal.new_for_user(@user)
      @penpal.save

      @user.penpal_id = @penpal.id
      @user.save
    end

    return redirect to("/system/penpal/#{@penpal.id}")
  end
end
