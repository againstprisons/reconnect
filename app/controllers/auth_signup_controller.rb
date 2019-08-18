class ReConnect::Controllers::AuthSignupController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return redirect "/" if logged_in?

    @title = t(:'auth/signup/title')

    @invite = request.params["invite"]&.strip&.downcase
    @invite = ReConnect::Models::Token.where(:token => @invite, :use => 'invite').first if @invite
    @invite.check_validity! if @invite
    @invite_data = {
      :token => @invite,
      :short => @invite ? @invite.token[0..7] : nil,
      :valid => @invite ? @invite.valid : false,
      :expired => @invite && @invite.expiry && Time.now >= @invite.expiry,
    }

    unless signups_enabled? || (@invite && @invite.valid)
      return haml(:'auth/layout', :locals => {:title => @title}) do
        haml(:'auth/signup_disabled', :layout => false, :locals => {
          :title => @title,
          :invite => @invite_data,
        })
      end
    end

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title}) do
        haml(:'auth/signup', :layout => false, :locals => {
          :title => @title,
          :invite => @invite_data,
        })
      end
    end

    errs = [
      request.params["first_name"].nil?,
      request.params["first_name"]&.strip.empty?,
      request.params["last_name"].nil?,
      request.params["last_name"]&.strip.empty?,
      request.params["email"].nil?,
      request.params["email"]&.strip.empty?,
      request.params["password"].nil?,
      request.params["password"].empty?,
      request.params["password_confirm"].nil?,
      request.params["password_confirm"].empty?,
    ]

    if ReConnect.app_config['signup-age-gate-enabled']
      errs << request.params["age_verify"].nil?
      errs << request.params["age_verify"].empty?
    end

    if errs.any?
      flash :error, t(:required_field_missing)
      return redirect request.path
    end

    if ReConnect.app_config['signup-age-gate-enabled']
      user_dob = request.params["age_verify"]&.strip&.downcase
      user_dob = Chronic.parse(user_dob, :guess => true)
      unless user_dob
        flash :error, t(:required_field_missing)
        return redirect request.path
      end

      age_gate = Chronic.parse(ReConnect.app_config['signup-age-gate'], :guess => true)
      if user_dob > age_gate
        flash :error, t(:'auth/signup/age_gate/error')
        return redirect request.path
      end
    end

    user_first_name = request.params["first_name"]&.strip
    user_last_name = request.params["last_name"]&.strip
    email = request.params["email"].strip.downcase
    password = request.params["password"]
    password_confirm = request.params["password_confirm"]

    # check if user exists with this email
    user_exists = ReConnect::Models::User.where(email: email).count.positive?
    if user_exists
      flash :error, t(:'auth/signup/email_already_used')
      return redirect request.path
    end

    # check password confirmation
    unless Rack::Utils.secure_compare(password, password_confirm)
      flash :error, t(:'auth/signup/password_confirm_incorrect')
      return redirect request.path
    end

    # if we get here, we can create the new user
    user = ReConnect::Models::User.new(email: email)
    user.password = password

    # save to get an ID
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

    # invalidate the invite if we're using one
    if @invite
      @invite.user_id = user.id
      @invite.invalidate!
      @invite.save
    end

    # send welcome email
    email_data = {
      :name => [user_first_name, user_last_name],
      :email => email,
    }

    queued_email = ReConnect::Models::EmailQueue.new_from_template("new_user_welcome", email_data)
    queued_email.queue_status = "queued"
    queued_email.encrypt(:subject, "Welcome to #{site_name}!") # TODO: translation
    queued_email.encrypt(:recipients, JSON.generate({"mode" => "list", "list" => [email]}))
    queued_email.save

    # log the user in
    token = user.login!
    session[:token] = token.token

    flash :success, t(:'auth/signup/success', :site_name => site_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect to("/")
  end
end
