class ReConnect::Controllers::PenpalCorrespondenceCreateController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index(ppid)
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @current_penpal = ReConnect::Models::Penpal[current_user.penpal_id]
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal

    @relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal, @current_penpal)
    return halt 404 unless @relationship

    @penpal_name = @penpal.get_name.first
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?

    @title = t(:'penpal/view/correspondence/create/title', :name => @penpal_name)

    if request.get?
      return haml :'penpal/correspondence_create', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :relationship => @relationship,
        :content => nil,
      }
    end

    content = request.params["content"]&.strip
    if content.nil? || content.empty?
      flash :error, t(:'penpal/view/correspondence/create/error/no_text')
      return redirect request.path
    end

    # Do a sanitize run
    content = Sanitize.fragment(content, Sanitize::Config::BASIC)

    # Run content filter
    filter = ReConnect.new_content_filter
    matched = filter.do_filter(content)
    if matched.count.positive?
      flash :error, t(:'penpal/view/correspondence/create/error/content_filter_matched', :matched => matched)
      return haml :'penpal/correspondence_create', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :relationship => @relationship,
        :content => content,
      }
    end

    # Save as file object
    obj = ReConnect::Models::File.upload(content, :filename => "#{DateTime.now.strftime("%Y-%m-%d_%H%M%S")}.html")
    obj.mime_type = "text/html"
    obj.save

    # create the correspondence
    c = ReConnect::Models::Correspondence.new
    c.creation = Time.now
    c.creating_user = current_user.id
    c.file_id = obj.file_id
    c.sending_penpal = @current_penpal.id
    c.receiving_penpal = @penpal.id
    c.save

    c.send!

    flash :success, t(:'penpal/view/correspondence/create/success')
    return redirect to("/penpal/#{@penpal.id}/correspondence/#{c.id}")
  end
end
