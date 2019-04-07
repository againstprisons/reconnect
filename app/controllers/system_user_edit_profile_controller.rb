class ReConnect::Controllers::SystemUserEditProfileController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:edit")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @name = @user.decrypt(:name)
    @email = @user.email

    @title = t(:'system/user/edit_profile/title', :name => @name, :id => @user.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/user/edit_profile', :layout => false, :locals => {
          :title => @title,
          :user => @user,
          :user_name => @name,
          :user_email => @email,
        })
      end
    end

    new_name = request.params["name"]&.strip
    new_email = request.params["email"]&.strip&.downcase

    if new_name.nil? || new_name == "" || new_email.nil? || new_email == ""
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    changed = false

    if @name != new_name
      @user.encrypt(:name, new_name)
      changed = true
    end

    if @user.email != new_email
      # check no user already exists with this email address
      if ReConnect::Models::User.where(:email => new_email).count.positive?
        flash :error, t(:'system/user/edit_profile/email_already_used')
        return redirect request.path
      end

      # set email
      @user.email = new_email
      changed = true
    end

    if changed
      @user.save

      penpal = ReConnect::Models::Penpal[@user.penpal_id]
      if penpal
        ReConnect::Models::PenpalFilter.clear_filters_for(penpal)
        ReConnect::Models::PenpalFilter.create_filters_for(penpal)
      end
    end

    flash :success, t(:'system/user/edit_profile/success')
    return redirect request.path
  end
end
