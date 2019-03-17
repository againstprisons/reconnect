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

    @title = t(:'penpal/view/correspondence/create/title', :name => @penpal.get_name)

    if request.get?
      return haml :'penpal/correspondence_create', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal.get_name,
        :relationship => @relationship,
      }
    end

    unless params[:file]
      flash :error, t(:'penpal/view/correspondence/create/error/no_file')
      return redirect request.path
    end

    # upload the file
    begin
      fn = params[:file][:filename]
      params[:file][:tempfile].rewind
      data = params[:file][:tempfile].read

      obj = ReConnect::Models::File.upload(data, :filename => fn)
      obj.save

    rescue => e
      flash :error, t(:'penpal/view/correspondence/create/error/upload_error')
      return redirect request.path
    end

    # create the correspondence
    c = ReConnect::Models::Correspondence.new
    c.creation = Time.now
    c.creating_user = current_user.id
    c.file_id = obj.file_id
    c.sending_penpal = @current_penpal.id
    c.receiving_penpal = @penpal.id
    c.save

    c.send_alert!

    flash :success, t(:'penpal/view/correspondence/create/success')
    return redirect to("/penpal/#{@penpal.id}/correspondence/#{c.id}")
  end
end
