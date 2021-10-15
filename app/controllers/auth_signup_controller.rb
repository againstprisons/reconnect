class ReConnect::Controllers::AuthSignupController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"
  add_route :get, "/verify/:token", method: :verify

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
        haml(:'auth/signup/disabled', :layout => false, :locals => {
          :title => @title,
          :invite => @invite_data,
        })
      end
    end

    @captcha = session[:captcha]
    @captcha ||= captcha_generate()
    session[:captcha] = @captcha

    if request.get?
      return haml(:'auth/layout', :locals => {:title => @title}) do
        haml(:'auth/signup/index', :layout => false, :locals => {
          :title => @title,
          :invite => @invite_data,
          :captcha => @captcha,
        })
      end
    end

    errs = [
      request.params["first_name"].nil?,
      request.params["first_name"]&.strip&.empty?,
      request.params["last_name"].nil?,
      request.params["last_name"]&.strip&.empty?,
      request.params["email"].nil?,
      request.params["email"]&.strip&.empty?,
      request.params["password"].nil?,
      request.params["password"]&.empty?,
      request.params["password_confirm"].nil?,
      request.params["password_confirm"]&.empty?,
    ]

    if errs.any?
      flash :error, t(:required_field_missing)
      return redirect request.path
    end

    if @captcha
      session.delete(:captcha)

      unless captcha_verify(@captcha, request.params['captcha']&.strip)
        flash :error, t(:'captcha/invalid')
        return redirect request.path
      end
    end

    if ReConnect.app_config['signup-age-gate-enabled']
      age_day = sprintf("%02d", request.params["age_day"].to_i)
      age_month = sprintf("%02d", request.params["age_month"].to_i)
      age_year = sprintf("%04d", request.params["age_year"].to_i)

      user_dob = Chronic.parse("#{age_year}-#{age_month}-#{age_day} 00:00:00")
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

    if ReConnect.app_config['signup-terms-agree-enabled']
      if request.params["terms_agree"]&.strip&.downcase != 'on'
        flash :error, t(:required_field_missing)
        return redirect request.path
      end
    end

    user_first_name = request.params["first_name"]&.strip
    user_last_name = request.params["last_name"]&.strip
    email = request.params["email"].strip.downcase
    password = request.params["password"]
    password_confirm = request.params["password_confirm"]

    if ReConnect::Models::EmailBlock.is_blocked?(email)
      flash :error, t(:'auth/signup/email_block')
      return redirect request.path
    end

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

    # invalidate the invite if we're using one
    if @invite
      @invite.invalidate!
      @invite.save
    end

    # hash password
    pwhash = ReConnect::Crypto.password_hash(password)

    # gather our user information
    user_data = {
      'email_address' => email,
      'password_hash' => pwhash,
      'name_first' => user_first_name,
      'name_last' => user_last_name,
      'invite' => @invite&.id,
    }

    # create an email verify token and store our user's data on that
    # as a JSON dump in the token extra data field
    verify_token = ReConnect::Models::Token.generate.update(use: 'user_create_verify').save
    verify_token.expiry = Chronic.parse('in 3 days')
    verify_token.encrypt(:extra_data, JSON.generate(user_data))
    verify_token.save

    # send confirmation email
    verify_email = ReConnect::Models::EmailQueue.new_from_template("new_user_verify", {
      :name => [user_first_name, user_last_name],
      :email => email,
      :verify_url => url("/auth/signup/verify/#{verify_token.token}"),
      :token_expiry => verify_token.expiry,
    })
    verify_email.queue_status = "queued"
    verify_email.encrypt(:subject, "Verify your #{site_name} account")
    verify_email.encrypt(:recipients, JSON.generate({"mode" => "list", "list" => [email]}))
    verify_email.save

    # render confirmation page
    return haml(:'auth/layout', :locals => {:title => @title, :auth_no_tabs => true}) do
      haml(:'auth/signup/verify_sent', :layout => false, :locals => {
        :title => @title,
      })
    end
  end

  def verify(token)
    begin
      token = ReConnect::Models::Token.where(token: token, use: 'user_create_verify').first
      throw "aaaaa" unless token

      user_data = JSON.parse(token.decrypt(:extra_data))
      throw "?????" unless user_data.keys.include?("email_address")
      throw "?????" unless user_data.keys.include?("password_hash")

    rescue
      return haml(:'auth/layout', :locals => {:title => @title, :auth_no_tabs => true}) do
        haml(:'auth/signup/verify_invalid', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    # create the user
    user = ReConnect::Models::User.new({
      email: user_data['email_address'],
      password_hash: user_data['password_hash'],
    }).save
    user.encrypt(:first_name, user_data['name_first'])
    user.encrypt(:last_name, user_data['name_last'])
    user.save

    # create penpal and generate filters
    penpal = ReConnect::Models::Penpal.new_for_user(user)
    penpal.save
    user.penpal_id = penpal.id
    user.save
    ReConnect::Models::PenpalFilter.create_filters_for(penpal)

    # if there was an invite ID in the data, invalidate that invite
    invite = ReConnect::Models::Token[user_data['invite']]
    if invite
      invite.user_id = user.id
      invite.invalidate!
      invite.save
    end

    # we haven't failed! delete the user_create_verify token
    token.delete

    # send welcome email
    email_data = {
      :name => user.get_name,
      :email => user.email,
    }

    welcome_email = ReConnect::Models::EmailQueue.new_from_template("new_user_welcome", email_data)
    welcome_email.queue_status = "queued"
    welcome_email.encrypt(:subject, "Welcome to #{site_name}!") # TODO: translation
    welcome_email.encrypt(:recipients, JSON.generate({"mode" => "list", "list" => [user.email]}))
    welcome_email.save

    # generate new user alert email, if enabled
    if should_send_alert_email('new_user')
      alert_data = {
        :name => user.get_name.compact.join(" "),
        :email => user.email,
        :userlink => url("/system/user/#{user.id}"),
      }

      alert_email = ReConnect::Models::EmailQueue.new_from_template('alert_new_user', alert_data)
      alert_email.queue_status = 'queued'
      alert_email.encrypt(:subject, "A new user has signed up")
      alert_email.encrypt(:recipients, JSON.generate({
        "mode" => "list",
        "list" => [ReConnect.app_config['site-alert-emails']['email']],
      }))
      alert_email.save
    end

    # log the user in
    token = user.login!
    session[:token] = token.token
    token.update(extra_data: JSON.generate({
      ip_address: request.ip,
      user_agent: request.user_agent,
    }))

    flash :success, t(:'auth/signup/success', :site_name => site_name)

    after_login = session.delete(:after_login)
    return redirect after_login if after_login
    redirect to("/")
  end
end
