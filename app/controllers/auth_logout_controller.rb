class ReConnect::Controllers::AuthLogoutController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return redirect "/auth" unless logged_in?

    token = current_token
    token.valid = false
    token.save

    session.delete(:token)

    flash :success, t(:'auth/logout/success')
    redirect '/auth'
  end
end
