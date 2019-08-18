class ReConnect::Controllers::SystemUserEditProfileController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:edit")

    @user = ReConnect::Models::User[uid.to_i]
    return halt 404 unless @user
    @name_a = @user.get_name
    @name = @name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    @pseudonym = @user.decrypt(:pseudonym)
    @email = @user.email

    @title = t(:'system/user/edit_profile/title', :name => @name, :id => @user.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/user/edit_profile', :layout => false, :locals => {
          :title => @title,
          :user => @user,
          :user_name => @name,
          :user_name_a => @name_a,
          :user_pseudonym => @pseudonym,
          :user_email => @email,
        })
      end
    end

    new_email = request.params["email"]&.strip&.downcase
    new_name_first = request.params["first_name"]&.strip
    new_name_last = request.params["last_name"]&.strip
    new_name_a = [new_name_first, new_name_last]
    new_pseudonym = request.params["pseudonym"]&.strip
    new_pseudonym = nil if new_pseudonym&.empty?

    none_of = [
      new_email.nil?,
      new_email&.empty?,
      new_name_first.nil?,
      new_name_first&.empty?,
      new_name_last.nil?,
      new_name_last&.empty?,
    ]

    if none_of.any?
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    changed = false

    if @name_a != new_name_a
      @user.encrypt(:first_name, new_name_first)
      @user.encrypt(:last_name, new_name_last)
      changed = true
    end

    if @pseudonym != new_pseudonym
      if new_pseudonym
        @user.encrypt(:pseudonym, new_pseudonym)
      else
        @user.pseudonym = nil
      end

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
