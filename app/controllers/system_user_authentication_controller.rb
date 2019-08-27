class ReConnect::Controllers::SystemUserAuthenticationController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:auth_options")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @pseudonym = @user.get_pseudonym
    @name_a = @user.get_name
    @name = @name_a.map{|x| x == "" ? nil : x}.compact.join(" ") || "(unknown)"
    @email = @user.email

    @title = t(:'system/user/auth_options/title', :name => @name, :pseudonym => @pseudonym, :id => @user.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/user/auth_options', :layout => false, :locals => {
          :title => @title,
          :user => @user,
          :user_name => @name,
          :user_pseudonym => @pseudonym,
          :user_email => @email,
        })
      end
    end

    action = request.params["action"]&.strip&.downcase
    unless %w[pwreset invalidate].include?(action)
      flash :error, t(:'invalid_action')
      return redirect request.path
    end

    if action == "pwreset"
      unless request.params["confirm"]&.strip&.downcase == "on"
        flash :error, t(:'system/user/auth_options/password_reset/confirm_not_checked')
        return redirect request.path
      end

      data = @user.password_reset!
      queue_id = data.last.id

      flash :success, t(:'system/user/auth_options/password_reset/success', :name => @name, :email => @email, :queue_id => queue_id)

    elsif action == "invalidate"
      unless request.params["confirm"]&.strip&.downcase == "on"
        flash :error, t(:'system/user/auth_options/invalidate/confirm_not_checked')
        return redirect request.path
      end

      @user.invalidate_tokens!
      flash :success, t(:'system/user/auth_options/invalidate/success', :name => @name)
    end

    return redirect request.path
  end
end
