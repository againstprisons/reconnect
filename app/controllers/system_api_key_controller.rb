class ReConnect::Controllers::SystemApiKeyController < ReConnect::Controllers::ApplicationController
  add_route :get, '/'
  add_route :post, '/create', method: :create
  add_route :get, '/revoke/:tid', method: :revoke
  add_route :post, '/revoke/:id', method: :revoke

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:apikey:access")
    @user = current_user
  end

  def index
    @title = t(:'system/apikey/title')
    @my_apikeys = ReConnect::Models::Token.where(user_id: @user.id, use: 'apikey').map do |k|
      {
        :id => k.id,
        :creation => k.creation,
        :expiry => k.expiry,
        :valid => k.check_validity!,
        :name => k.decrypt(:extra_data),
      }
    end.sort { |a, b| b[:creation] <=> a[:creation] }

    return haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/apikey/index', layout: false, locals: {
        title: @title,
        my_apikeys: @my_apikeys,
      })
    end
  end

  def create
    return halt 404 unless has_role?("system:apikey:create")

    @name = request.params['name']&.strip
    @name = nil if @name&.empty?
    unless @name
      flash :error, t(:'required_field_missing')
      return redirect url("/system/apikey")
    end

    @expiry_v = request.params['expiry']&.strip
    @expiry_v = nil if @expiry_v&.empty?
    @expiry = Chronic.parse(@expiry_v)
    if @expiry.nil? && !@expiry_v.nil?
      flash :warning, t(:'system/apikey/create/warnings/invalid_expiry')
    end

    @token = ReConnect::Models::Token.generate
    @token.use = 'apikey'
    @token.expiry = @expiry
    @token.user_id = @user.id
    @token.save
    @token.encrypt(:extra_data, @name)
    @token.save

    flash :success, t(:'system/apikey/create/success', name: @name, token: @token.token)
    redirect url("/system/apikey")
  end

  def revoke(tid)
    @token = ReConnect::Models::Token[tid.to_i]
    return halt 404 unless @token
    return halt 404 unless @token.use == 'apikey'
    return halt 404 unless @token.user_id == @user.id

    @name = @token.decrypt(:extra_data)
    @title = t(:'system/apikey/revoke/title', name: @name)

    # Generate a verification code and store it in the session if one
    # doesn't already exist there
    if session.key?(:apikey_revoke_confirm_code)
      @verify_code = session[:apikey_revoke_confirm_code]
    else
      @verify_code = Random.new.rand(100000000 .. 999999999).to_s
      session[:apikey_revoke_confirm_code] = @verify_code
    end

    # Render revocation request page
    if request.get?
      return haml(:'system/layout', locals: {title: @title}) do
        haml(:'system/apikey/revoke', layout: false, locals: {
          title: @title,
          token: @token,
          token_name: @name,
          verify_code: @verify_code,
        })
      end
    end

    # Check verification code
    form_verify = request.params['verify']&.strip
    if form_verify
      form_verify = form_verify.split(' ').map{|x| x.split('-')}.flatten.join('')
    end
    if form_verify != session[:apikey_revoke_confirm_code]
      flash :error, t(:'system/apikey/revoke/errors/invalid_code')
      return redirect request.path
    end
    session.delete(:apikey_revoke_confirm_code)

    # Revoke API key
    @token.invalidate!

    flash :success, t(:'system/apikey/revoke/success', name: @name)
    redirect url("/system/apikey")
  end
end
