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

    @current_user = current_user
    @current_penpal = ReConnect::Models::Penpal[@current_user.penpal_id]
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal

    @penpal_prison = ReConnect::Models::Prison[@penpal.decrypt(:prison_id).to_i]
    return halt 404 unless @penpal_prison

    @relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal, @current_penpal)
    return halt 404 unless @relationship

    @penpal_status = @penpal.decrypt(:status)&.strip
    @sending_enabled = !(ReConnect.app_config['penpal-status-disable-sending'].include?(@penpal_status))
    @sending_enabled = false if @penpal_status.nil? || @penpal_status.empty?
    @sending_enabled = false if @relationship.status_override
    @sending_enabled = false if ReConnect.app_config['disable-outside-correspondence-creation']
    return halt 404 unless @sending_enabled

    @penpal_name = @penpal.get_pseudonym
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?

    @title = t(:'penpal/view/correspondence/create/title', :name => @penpal_name)

    # Check if prison requires a PRN, and if it does, check that this penpal has one set
    if @penpal_prison.require_prn
      prn = @penpal.decrypt(:prisoner_number)
      if prn.nil? || prn&.empty?
        flash :error, t(:'penpal/view/correspondence/create/errors/prison_requires_prn')
        return redirect back
      end
    end

    force_compose = request.params["compose"]&.strip&.downcase == "1"

    content = nil
    pseudonym = @current_penpal.get_pseudonym
    if request.post?
      content = request.params["content"]&.strip
      content = nil if content&.empty?
      pseudonym = request.params["pseudonym"]&.strip

      if content.nil? || content&.empty?
        flash :error, t(:'penpal/view/correspondence/create/errors/no_text')
        force_compose = true
      end

      if pseudonym.nil? || pseudonym&.empty?
        flash :error, t(:'penpal/view/correspondence/create/errors/no_pseudonym')
        force_compose = true
      end
    end

    if request.get? || force_compose
      return haml :'penpal/correspondence_create/index', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :relationship => @relationship,
        :content => content,
        :pseudonym => pseudonym,
      }
    end

    # Remove invalid characters and do a sanitize run
    content.gsub!(/[^[:print:]]/, "\uFFFD")
    content = Sanitize.fragment(content, Sanitize::Config::RELAXED)

    # Get word count
    wordcount = Sanitize.fragment(content).scan(/\w+/).count

    # If the prison being sent to has a word count limit, check the limit
    if @penpal_prison.word_limit&.positive?
      if wordcount > @penpal_prison.word_limit
        flash :error, t(:'penpal/view/correspondence/create/errors/over_prison_word_limit')
        return haml :'penpal/correspondence_create/index', :locals => {
          :title => @title,
          :penpal => @penpal,
          :penpal_name => @penpal_name,
          :relationship => @relationship,
          :content => content,
          :pseudonym => pseudonym,
        }
      end
    end

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
        :pseudonym => pseudonym,
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
        :pseudonym => pseudonym,
      }
    end

    # Append signature to content, now that we've confirmed the content
    content = "#{content}\n<p>&mdash;<br>From: #{ERB::Util.html_escape(pseudonym)}</p>"

=begin
    # If needed, save new pseudonym on current user & regenerate filters
    if pseudonym != @current_user.get_pseudonym
      @current_user.encrypt(:pseudonym, pseudonym)
      @current_user.save
      ReConnect::Models::PenpalFilter.clear_filters_for(@current_penpal)
      ReConnect::Models::PenpalFilter.create_filters_for(@current_penpal)
    end
=end

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

    return halt 404 if ReConnect.app_config['disable-outside-file-upload']

    @current_penpal = ReConnect::Models::Penpal[current_user.penpal_id]
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal

    @relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal, @current_penpal)
    return halt 404 unless @relationship

    @penpal_status = @penpal.decrypt(:status)&.strip
    @sending_enabled = !(ReConnect.app_config['penpal-status-disable-sending'].include?(@penpal_status))
    @sending_enabled = false if @penpal_status.nil? || @penpal_status.empty?
    @sending_enabled = false if @relationship.status_override
    @sending_enabled = false if ReConnect.app_config['disable-outside-correspondence-creation']
    return halt 404 unless @sending_enabled

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
