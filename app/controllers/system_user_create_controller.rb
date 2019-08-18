class ReConnect::Controllers::SystemUserCreateController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")

    @title = t(:'system/user/create/title')

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/user/create', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    user_first_name = request.params["first_name"]&.strip
    user_last_name = request.params["last_name"]&.strip
    email = request.params["email"]&.strip&.downcase

    # check if user with this email exists
    user_exists = ReConnect::Models::User.where(email: email).count.positive?
    if user_exists
      flash :error, t(:'system/user/create/errors/email_already_used')
      return redirect request.path
    end

    # check names
    errs = [
      user_first_name.nil?,
      user_first_name&.empty?,
      user_last_name.nil?,
      user_last_name&.empty?
    ]

    if errs.any?
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    # if we get here, we can create the new user
    user = ReConnect::Models::User.new(email: email)
    user.save

    # save name
    user.encrypt(:first_name, user_first_name)
    user.encrypt(:last_name, user_last_name)
    user.save

    # create penpal and generate filters
    penpal = ReConnect::Models::Penpal.new_for_user(user)
    penpal.save
    user.penpal_id = penpal.id
    user.save
    ReConnect::Models::PenpalFilter.create_filters_for(penpal)

    # send reset if requested
    if request.params["password_reset"]&.strip&.downcase == "on"
      user.password_reset!
    end

    # flash and redirect to new user page
    flash :success, t(:'system/user/create/success', :uid => user.id)
    return redirect to("/system/user/#{user.id}")
  end
end
