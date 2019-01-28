class ReConnect::Controllers::SystemPenpalAssociateUserController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name

    @user = nil
    @user = @penpal.user if !@penpal.user_id.nil?
    @user_name = nil
    @user_name = @user.decrypt(:name) if @user

    @title = t(:'system/penpal/associate/title', :name => @name, :id => @penpal.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/associate', :layout => false, :locals => {
          :title => @title,
          :penpal => @penpal,
          :name => @name,
          :user => @user,
          :user_name => @user_name,
        })
      end
    end

    new_user_id = request.params["userid"]&.strip.to_i
    if new_user_id.zero?
      unless request.params["confirm"]&.strip&.downcase == "on"
        flash :error, t(:'system/penpal/associate/remove_association/confirm_not_checked')
        return redirect request.path
      end

      unless @user
        flash :error, t(:'system/penpal/associate/remove_association/not_removing_no_association')
        return redirect request.path
      end

      @penpal.user_id = nil
      @penpal.save
      @user.penpal_id = nil
      @user.save

      flash :success, t(:'system/penpal/associate/remove_association/success')

    else
      new_user = ReConnect::Models::User[new_user_id]
      unless new_user
        flash :error, t(:'system/penpal/associate/add_association/user_does_not_exist')
        return redirect request.path
      end

      unless new_user.penpal_id.nil?
        flash :error, t(:'system/penpal/associate/add_association/user_already_associated')
        return redirect request.path
      end

      @penpal.user_id = new_user.id
      @penpal.save
      new_user.penpal_id = @penpal.id
      new_user.save

      new_user_name = new_user.decrypt(:name) || "(unknown)"
      flash :success, t(:'system/penpal/associate/add_association/success', :user_id => new_user.id, :user_name => new_user_name)

    end

    return redirect request.path
  end
end
