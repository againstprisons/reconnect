class ReConnect::Controllers::SystemUserController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/by-id", :method => :by_id
  add_route :post, "/by-email", :method => :by_email
  add_route :post, "/create-invite", :method => :create_invite

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")

    @title = t(:'system/user/title')

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/user/index', :layout => false, :locals => {
        :title => @title,
      })
    end
  end

  def by_id
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")

    id = request.params["id"]&.strip.to_i
    if id.zero?
      flash :error, t(:'system/user/search_failed')
      return redirect to('/system/user')
    end

    user = ReConnect::Models::User[id]
    unless user
      flash :error, t(:'system/user/search_failed')
      return redirect to('/system/user')
    end

    redirect to("/system/user/#{user.id}")
  end

  def by_email
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")

    email = request.params["email"]&.strip&.downcase
    if email.nil? || email == ""
      flash :error, t(:'system/user/search_failed')
      return redirect to('/system/user')
    end

    user = ReConnect::Models::User.where(:email => email).first
    unless user
      flash :error, t(:'system/user/search_failed')
      return redirect to('/system/user')
    end

    redirect to("/system/user/#{user.id}")
  end

  def create_invite
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:user:access")

    # TODO: parse expiry from request.params["expiry"]
    expiry = Time.now + (60 * 60 * 24) # 1 day

    # create token
    token = ReConnect::Models::Token.generate
    token.use = "invite"
    token.expiry = expiry
    token.save

    # create invite url
    url = Addressable::URI.parse(ReConnect.app_config["base-url"])
    url += "/auth/signup"
    url.query_values = {"invite" => token.token}

    # flash and return
    flash :success, t(:'system/user/create_invite/success', :link => url.to_s)
    return redirect back
  end
end
