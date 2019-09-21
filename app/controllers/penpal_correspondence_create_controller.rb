class ReConnect::Controllers::PenpalCorrespondenceCreateController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"
  add_route :post, "/file", :method => :file

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

    @penpal_status = @penpal.decrypt(:status)&.strip
    @sending_enabled = !(ReConnect.app_config['penpal-status-disable-sending'].include?(@penpal_status))
    @sending_enabled = false if @penpal_status.nil? || @penpal_status.empty?
    return halt 418 unless @sending_enabled

    @penpal_name = @penpal.get_pseudonym
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?

    @title = t(:'penpal/view/correspondence/create/title', :name => @penpal_name)

    force_compose = request.params["compose"]&.strip&.downcase == "1"
    content = nil
    if request.post?
      content = request.params["content"]&.strip
      content = nil if content.nil? || content.empty?
    end

    if request.get? || force_compose
      return haml :'penpal/correspondence_create/index', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :relationship => @relationship,
        :content => content,
      }
    end

    if content.nil? || content.empty?
      flash :error, t(:'penpal/view/correspondence/create/errors/no_text')
      return redirect to("/penpal/#{ppid}/correspondence/create")
    end

    # Do a sanitize run
    content = Sanitize.fragment(content, Sanitize::Config::RELAXED)

    # Run content filter
    filter = ReConnect.new_content_filter
    matched = filter.do_filter(content)
    if matched.count.positive?
      flash :error, t(:'penpal/view/correspondence/create/errors/content_filter_matched', :matched => matched)
      return haml :'penpal/correspondence_create/index', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :relationship => @relationship,
        :content => content,
      }
    end

    # Either show confirmation screen, or submit correspondence
    confirmed = request.params["confirm"]&.strip&.downcase == "1"
    unless confirmed
      return haml :'penpal/correspondence_create/preview', :locals => {
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

  def file(ppid)
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    return halt 404 unless ReConnect.app_config['allow-outside-file-upload']

    @current_penpal = ReConnect::Models::Penpal[current_user.penpal_id]
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal

    @relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal, @current_penpal)
    return halt 404 unless @relationship

    @penpal_status = @penpal.decrypt(:status)&.strip
    @sending_enabled = !(ReConnect.app_config['penpal-status-disable-sending'].include?(@penpal_status))
    @sending_enabled = false if @penpal_status.nil? || @penpal_status.empty?
    return halt 418 unless @sending_enabled

    @penpal_name = @penpal.get_pseudonym
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?

    unless params[:file]
      flash :error, t(:'penpal/view/correspondence/create/errors/no_file')
      return redirect to("/penpal/#{ppid}/correspondence/create")
    end

    # upload the file
    begin
      fn = params[:file][:filename]
      params[:file][:tempfile].rewind
      data = params[:file][:tempfile].read

      obj = ReConnect::Models::File.upload(data, :filename => fn)
    rescue
      flash :error, t(:'penpal/view/correspondence/create/errors/upload_failed')
      return redirect to("/penpal/#{ppid}/correspondence/create")
    end

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
