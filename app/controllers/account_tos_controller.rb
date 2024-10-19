class ReConnect::Controllers::AccountTosController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless ReConnect.app_config['tos-enabled']
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @user = current_user

    if request.post?
      is_ok = request.params['agreed']&.strip&.downcase == "on"
      if ReConnect.app_config['tos-checklist'].length > 0
        is_ok = ReConnect.app_config['tos-checklist'].map.with_index(0) do |_, chidx|
          request.params["checklist_#{chidx}"]&.strip&.downcase == "on"
        end.all?
      end

      if is_ok
        @user.update(tos_agreed: Sequel.function(:NOW))
        return redirect to('/')
      end

      flash :error, t(:'account/tos/sign_form/validation_failed')
    end

    @title = t(:'account/tos/title')
    haml(:'account/layout', :locals => {:title => @title}) do
      haml(:'account/tos', :layout => false, :locals => {
        :title => @title,
        :tos_agreed => (@user.tos_agreed || Time.at(0)) > ReConnect.app_config['tos-last-updated'],
        :tos_text => ReConnect.app_config['tos-text'],
        :tos_checklist => ReConnect.app_config['tos-checklist'],
      })
    end
  end
end
