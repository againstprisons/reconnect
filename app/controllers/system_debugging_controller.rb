class ReConnect::Controllers::SystemDebuggingController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/flash", :method => :test_flash
  add_route :post, "/email", :method => :test_email
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

    queue_entry = ReConnect::Models::EmailQueue.new
    queue_entry.save
    queue_entry.queue_status = 'queued'
    queue_entry.encrypt(:recipients, recipients)
    queue_entry.encrypt(:subject, subject)
    queue_entry.encrypt(:content_text, content_text)
    queue_entry.encrypt(:content_html, content_html)
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
end
