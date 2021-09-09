class ReConnect::Controllers::PenpalCorrespondenceController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/mark", :method => :mark
  add_route :get, "/download", :method => :download

  def index(ppid, cid)
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

    @penpal_name = @penpal.get_pseudonym
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?

    @title = t(:'penpal/view/correspondence/single/title', :name => @penpal_name)

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @current_penpal.id || @correspondence.receiving_penpal == @current_penpal.id
    return halt 404 unless @correspondence.sending_penpal == @penpal.id || @correspondence.receiving_penpal == @penpal.id

    @correspondence_d = [@correspondence].map{|x| x.get_data(@current_penpal)}.first

    @file = ReConnect::Models::File.where(:file_id => @correspondence.file_id).first
    return halt 404 unless @file
    @file_token = @file.generate_download_token(current_user)
    @file_d = {
      :mime_type => @file.mime_type,
      :display_embed => @file.mime_type == 'application/pdf',
      :display_html => @file.mime_type == 'text/html',
      :html_content => @file.mime_type == 'text/html' ? @file.decrypt_file : nil,
      :download_token => @file_token,
      :download_url => url("/filedl/#{@file.file_id}/#{@file_token.token}?v=0"),
      :view_url => url("/filedl/#{@file.file_id}/#{@file_token.token}?v=1"),
    }

    haml :'penpal/correspondence', :locals => {
      :title => @title,
      :penpal => @penpal,
      :penpal_name => @penpal_name,
      :relationship => @relationship,
      :correspondence => @correspondence,
      :correspondence_d => @correspondence_d,
      :file => @file,
      :file_d => @file_d,
    }
  end

  def mark(ppid, cid)
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

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @current_penpal.id || @correspondence.receiving_penpal == @current_penpal.id
    return halt 404 unless @correspondence.sending_penpal == @penpal.id || @correspondence.receiving_penpal == @penpal.id

    @correspondence_d = [@correspondence].map{|x| x.get_data(@current_penpal)}.first
    return halt 404 if @correspondence_d[:this_user_sent]

    if @correspondence.actioning_user.nil?
      @correspondence.actioning_user = current_user.id
      flash :success, t(:'penpal/view/correspondence/single/mark/read/success')
    else
      @correspondence.actioning_user = nil
      flash :success, t(:'penpal/view/correspondence/single/mark/unread/success')
    end

    @correspondence.save
    return redirect back
  end

  def download(ppid, cid)
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

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @current_penpal.id || @correspondence.receiving_penpal == @current_penpal.id
    return halt 404 unless @correspondence.sending_penpal == @penpal.id || @correspondence.receiving_penpal == @penpal.id

    @file = ReConnect::Models::File.where(:file_id => @correspondence.file_id).first
    return halt 404 unless @file

    @token = @file.generate_download_token(current_user)

    return redirect to("/filedl/#{@file.file_id}/#{@token.token}")
  end
end
