class ReConnect::Controllers::SystemPenpalRelationshipCorrespondenceCreateController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"
  add_route :get, "/text", :method => :text
  add_route :post, "/text", :method => :text

  def index(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_one_name = "(unknown)" if @penpal_one_name.nil? || @penpal_one_name&.strip&.empty?
    @penpal_one_pseudonym = @penpal_one.get_pseudonym
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_two_name = "(unknown)" if @penpal_two_name.nil? || @penpal_two_name&.strip&.empty?
    @penpal_two_pseudonym = @penpal_two.get_pseudonym

    @title = t(:'system/penpal/relationship/correspondence/create/title', {
      :one_name => @penpal_one_name,
      :one_pseudonym => @penpal_one_pseudonym,
      :two_name => @penpal_two_name,
      :two_pseudonym => @penpal_two_pseudonym,
    })

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/relationship/correspondence/create/index', :layout => false, :locals => {
          :title => @title,
          :relationship => @relationship,
          :penpal_one => @penpal_one,
          :penpal_one_name => @penpal_one_name,
          :penpal_one_pseudonym => @penpal_one_pseudonym,
          :penpal_two => @penpal_two,
          :penpal_two_name => @penpal_two_name,
          :penpal_two_pseudonym => @penpal_two_pseudonym,
        })
      end
    end

    # get direction
    direction = request.params["direction"]&.strip&.downcase
    if direction.nil? || direction.empty?
      flash :error, t(:'required_field_missing')
      return redirect to("/system/penpal/relationship/#{rid}/correspondence/create")
    end

    unless params[:file]
      flash :error, t(:'system/penpal/relationship/correspondence/create/errors/no_file')
      return redirect to("/system/penpal/relationship/#{rid}/correspondence/create")
    end

    # upload the file
    begin
      fn = params[:file][:filename]
      params[:file][:tempfile].rewind
      data = params[:file][:tempfile].read

      obj = ReConnect::Models::File.upload(data, :filename => fn)

      # do a quick check here to see if the data has "<p>" in it. if it does,
      # assume it's HTML, and set the correct mime type on the file object.
      # the MimeMagic gem doesn't set the mime type if this is a partial
      # HTML file ( ie. no doctype or `<html>` ), and as such we need to do
      # this so that automatic emails into prisons work.
      #
      # XXX: this is a huge hack, do proper detection eventually
      if obj.mime_type.nil? || obj.mime_type.empty?
        if data.downcase.include?("<p>") && data.downcase.include?("</p>")
          obj.mime_type = "text/html"
        end
      end

      obj.save
    rescue => e
      flash :error, t(:'system/penpal/relationship/correspondence/create/errors/upload_failed')
      return redirect to("/system/penpal/relationship/#{rid}/correspondence/create")
    end

    # create the correspondence
    c = ReConnect::Models::Correspondence.new
    c.creation = Time.now
    c.creating_user = current_user.id
    c.file_id = obj.file_id

    receiving_penpal = nil
    if direction == "1to2"
      c.sending_penpal = @penpal_one.id
      c.receiving_penpal = @penpal_two.id
      receiving_penpal = @penpal_two
    else
      c.sending_penpal = @penpal_two.id
      c.receiving_penpal = @penpal_one.id
      receiving_penpal = @penpal_one
    end

    # if this is inside-to-outside correspondence, set the correspondence
    # object `sent` flag to "to_outside". this is so that we can easily filter
    # for outside-to-inside correspondence with the flag set to "no" - which
    # means they haven't automatically been sent, and require admin attention.
    if receiving_penpal.is_incarcerated == false
      c.sent = "to_outside"
    end

    c.save
    c.send!

    flash :success, t(:'system/penpal/relationship/correspondence/create/success', :id => c.id)
    return redirect to("/system/penpal/relationship/#{@relationship.id}/correspondence/#{c.id}")
  end

  def text(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_one_name = "(unknown)" if @penpal_one_name.nil? || @penpal_one_name&.strip&.empty?
    @penpal_one_pseudonym = @penpal_one.get_pseudonym
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_two_name = "(unknown)" if @penpal_two_name.nil? || @penpal_two_name&.strip&.empty?
    @penpal_two_pseudonym = @penpal_two.get_pseudonym

    @force_compose = request.params['force-compose']&.strip == '1'
    @content = request.params['content']&.strip
    @content = nil if @content&.empty?

    @title = t(:'system/penpal/relationship/correspondence/create/title', {
      :one_name => @penpal_one_name,
      :one_pseudonym => @penpal_one_pseudonym,
      :two_name => @penpal_two_name,
      :two_pseudonym => @penpal_two_pseudonym,
    })

    if request.get? || @force_compose
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/relationship/correspondence/create/text', :layout => false, :locals => {
          :title => @title,
          :relationship => @relationship,
          :penpal_one => @penpal_one,
          :penpal_one_name => @penpal_one_name,
          :penpal_one_pseudonym => @penpal_one_pseudonym,
          :penpal_two => @penpal_two,
          :penpal_two_name => @penpal_two_name,
          :penpal_two_pseudonym => @penpal_two_pseudonym,
          :content => @content,
        })
      end
    end

    # get direction
    direction = request.params["direction"]&.strip&.downcase
    if direction.nil? || direction.empty?
      flash :error, t(:'required_field_missing')
      return redirect to("/system/penpal/relationship/#{rid}/correspondence/create")
    end

    if @content.nil? || @content.empty?
      flash :error, t(:'system/penpal/relationship/correspondence/create/errors/no_text')
      return redirect to("/system/penpal/relationship/#{@relationship.id}/correspondence/create")
    end

    # Do a sanitize run
    @content = Sanitize.fragment(@content, Sanitize::Config::BASIC)

    # Render
    @rendered = @content
    @rendered = "data:text/html;base64,#{Base64.strict_encode64(@rendered)}"

    if request.params['confirm']&.strip != '1'
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/relationship/correspondence/create/text_confirm', :layout => false, :locals => {
          :title => @title,
          :relationship => @relationship,
          :penpal_one => @penpal_one,
          :penpal_one_name => @penpal_one_name,
          :penpal_one_pseudonym => @penpal_one_pseudonym,
          :penpal_two => @penpal_two,
          :penpal_two_name => @penpal_two_name,
          :penpal_two_pseudonym => @penpal_two_pseudonym,
          :direction => direction,
          :content => @content,
          :rendered => @rendered,
        })
      end
    end

    # Save as file object
    obj = ReConnect::Models::File.upload(@content, :filename => "#{DateTime.now.strftime("%Y-%m-%d_%H%M%S")}.html")
    obj.mime_type = "text/html"
    obj.save

    # create the correspondence
    c = ReConnect::Models::Correspondence.new
    c.creation = Time.now
    c.creating_user = current_user.id
    c.file_id = obj.file_id

    receiving_penpal = nil
    if direction == "1to2"
      c.sending_penpal = @penpal_one.id
      c.receiving_penpal = @penpal_two.id
      receiving_penpal = @penpal_two
    else
      c.sending_penpal = @penpal_two.id
      c.receiving_penpal = @penpal_one.id
      receiving_penpal = @penpal_one
    end

    # if this is inside-to-outside correspondence, set the correspondence
    # object `sent` flag to "to_outside". this is so that we can easily filter
    # for outside-to-inside correspondence with the flag set to "no" - which
    # means they haven't automatically been sent, and require admin attention.
    if receiving_penpal.is_incarcerated == false
      c.sent = "to_outside"
    end

    c.save
    c.send!

    flash :success, t(:'system/penpal/relationship/correspondence/create/success', :id => c.id)
    return redirect to("/system/penpal/relationship/#{@relationship.id}/correspondence/#{c.id}")
  end
end
