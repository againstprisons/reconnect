class ReConnect::Controllers::SystemDebuggingController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/flash", :method => :test_flash
  add_route :post, "/email", :method => :test_email
  add_route :post, "/filter-refresh", :method => :filter_refresh
  add_route :get, "/routes", :method => :routes
  add_route :post, "/error-pls", :method => :error_pls

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

    @title = t(:'system/debugging/title')
    @app_config = ReConnect.app_config

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/debugging/index', :layout => false, :locals => {
        :title => @title,
        :app_config => @app_config,
        :site_dir => ReConnect.site_dir,
      })
    end
  end

  def test_flash
    type = request.params["type"]&.strip&.downcase || 'success'
    flash type.to_sym, t(:'system/debugging/flash/message', :type => type.inspect)

    return redirect back
  end

  def test_email
    address = current_user.email

    subject = "Debug test email"
    content_text = "This is a test email for debugging purposes."
    content_html = "<p>This is a test email for debugging purposes.</p>"
    attachments = JSON.dump([
      {
        "filename" => "test_attachment.txt",
        "content" => "This is a test attachment text file.\n",
      },
    ])

    recipients = JSON.dump({
      "mode" => "list",
      "list" => [
        address,
      ],
    })

    queue_entry = ReConnect::Models::EmailQueue.new_from_template("debugging_test", {})
    queue_entry.queue_status = 'queued'
    queue_entry.encrypt(:recipients, recipients)
    queue_entry.encrypt(:subject, subject)
    queue_entry.encrypt(:attachments, attachments)
    queue_entry.save

    flash :success, t(:'system/debugging/email/success', :address => address, :queue_id => queue_entry.id)
    return redirect back
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

  def filter_refresh
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

    ReConnect::Workers::FilterRefreshWorker.perform_async
    flash :success, t(:'system/debugging/filter_refresh/success')

    return redirect back
  end

  def error_pls
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

    raise "This is a test exception!"
  end
end
