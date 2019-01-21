class ReConnect::Controllers::SystemDebuggingController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/flash", :method => :test_flash
  add_route :get, "/routes", :method => :routes

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

    @title = t(:'system/debugging/title')

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/debugging/index', :layout => false, :locals => {
        :title => @title
      })
    end
  end

  def test_flash
    type = request.params["type"]&.strip&.downcase
    if type.nil?
      flash :error, t(:required_field_missing)
      return redirect to("/system/debugging")
    end

    flash type.to_sym, t(:'system/debugging/flash/message', :type => type.inspect)

    return redirect to("/system/debugging")
  end

  def routes
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

    @title = t(:'system/debugging/routes/title')
    @routes = ReConnect::Route.all_routes.map do |k, v|
      r = {}
      v[:routes].each do |route|
        meth = "#{k}##{route[:method]}"
        r[meth] ||= {
          :path => route[:path][:full],
          :method => meth,
          :verbs => []
        }

        r[meth][:verbs] << route[:verb]
      end

      [k, r.map{|_, v| v}]
    end.to_h

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/debugging/routes', :layout => false, :locals => {
        :title => @title,
        :routes => @routes,
      })
    end
  end
end
