class ReConnect::Controllers::ApplicationController
  extend ReConnect::Route

  def initialize(app)
    @app = app
  end

  def method_missing(meth, *args, &bk)
    @app.instance_eval do
      self.send(meth, *args, &bk)
    end
  end

  def preflight
    # Check if maintenance mode
    if is_maintenance? && !maintenance_path_allowed?
      return halt 503, maintenance_render
    end

    # Set and check CSRF
    csrf_set!
    unless request.safe?
      return halt 403, "CSRF failed" unless csrf_ok?
    end

    if ReConnect::Models::IpBlock.is_blocked?(request.ip) && !current_prefix?('/static')
      return halt haml(:'auth/banned', :layout => :layout_minimal, :locals => {
        :title => t(:'auth/banned/title'),
      })
    end

    if current_user_is_disabled?
      return halt haml(:'auth/user_disabled', :layout => :layout_minimal, :locals => {
        :title => t(:'auth/user_disabled/title'),
        :reason => current_user.decrypt(:disabled_reason),
      })
    end
  end
end
