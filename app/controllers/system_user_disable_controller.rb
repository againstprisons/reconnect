class ReConnect::Controllers::SystemUserDisableController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:disable")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @name_a = @user.get_name
    @pseudonym = @user.get_pseudonym
    @name = @name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    @email = @user.email
    @disabled_reason = @user.decrypt(:disabled_reason)
    @disabled_reason = nil if @disabled_reason&.strip == ""

    @title = t(:'system/user/disable_delete/title', :name => @name, :pseudonym => @pseudonym, :id => @user.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/user/disable_delete', :layout => false, :locals => {
          :title => @title,
          :user => @user,
          :user_name => @name,
          :user_name_a => @name_a,
          :user_email => @email,
          :disabled_reason => @disabled_reason,
        })
      end
    end

    action = request.params["action"]&.strip&.downcase
    unless %w[disable delete].include?(action)
      flash :error, t(:'invalid_action')
      return redirect request.path
    end

    if action == "disable"
      reason = request.params["reason"]&.strip
      if reason.nil? || reason == ""
        # Enable user
        @user.disabled_reason = nil
        flash :success, t(:'system/user/disable_delete/disable/enable_success')
      else
        # Disable user
        @user.encrypt(:disabled_reason, reason)
        flash :success, t(:'system/user/disable_delete/disable/disable_success')
      end

      @user.save

    elsif action == "delete"
      unless request.params["confirm"]&.strip&.downcase == "on"
        flash :error, t(:'system/user/disable_delete/delete/confirm_not_checked')
        return redirect request.path
      end

      unless request.params["email"]&.strip&.downcase == @email
        flash :error, t(:'system/user/disable_delete/delete/email_not_valid')
        return redirect request.path
      end

      if request.params["ipban"]&.strip&.downcase == "on"
        @user.ip_ban_from_tokens!(current_user)
      end

      if request.params["emailban"]&.strip&.downcase == "on"
        ReConnect::Models::EmailBlock.new({
          email: @user.email.split('@', 2).last,
          is_domain: true,
          reason: "Domain block when deleting User[#{@user.id}] (#{@user.get_name.join(' ')}) (#{@user.email})",
          creator: current_user.id,
        }).save
      end

      @user.delete!
      flash :success, t(:'system/user/disable_delete/delete/success')

      return redirect "/system/user"
    end

    return redirect request.path
  end
end
