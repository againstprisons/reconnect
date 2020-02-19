class ReConnect::Controllers::SystemFilesInspectController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/download", :method => :download
  add_route :get, "/delete", :method => :delete
  add_route :post, "/delete", :method => :delete
  add_route :post, "/mime-type", :method => :mime_type
  add_route :post, "/replace", :method => :replace

  def index(fid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:files:inspect")

    @file = ReConnect::Models::File.where(:file_id => fid).first
    return halt 404 unless @file

    @title = t(:'system/files/inspect/title', :id => fid)

    if request.get?
      haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/files/inspect', :layout => false, :locals => {
          :title => @title,
          :file => @file,
        })
      end
    end
  end

  def download(fid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:files:inspect")

    @file = ReConnect::Models::File.where(:file_id => fid).first
    return halt 404 unless @file

    @token = @file.generate_download_token(current_user)

    return redirect to("/filedl/#{@file.file_id}/#{@token.token}")
  end

  def delete(fid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:files:inspect")

    @file = ReConnect::Models::File.where(:file_id => fid).first
    return halt 404 unless @file

    @title = t(:'system/files/delete/title', :id => fid)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/files/delete', :layout => false, :locals => {
          :title => @title,
          :file => @file,
        })
      end
    end

    if request.params["confirm"]&.strip&.downcase == "on"
      if request.params["enter_yes"]&.strip == "YES"
        @file.delete!
        flash :success, t(:'system/files/delete/success', :id => fid)
        return redirect to("/system/files")
      end
    end

    flash :error, t(:'system/files/delete/confirm_not_checked')
    redirect request.path
  end

  def mime_type(fid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:files:inspect")

    @file = ReConnect::Models::File.where(:file_id => fid).first
    return halt 404 unless @file

    mime = request.params["mime"]&.strip&.downcase
    if mime.empty?
      mime = nil
    end

    old = @file.mime_type
    @file.mime_type = mime
    @file.save

    flash :success, t(:'system/files/inspect/mime_type/success', :old => old, :new => mime)
    return redirect to("/system/files/#{@file.file_id}")
  end
  
  def replace(fid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:files:inspect")
    return halt 500 unless params[:file]
    
    @file = ReConnect::Models::File.where(:file_id => fid).first
    return halt 404 unless @file
    
    # Save old file hash so we can delete the file
    old_digest = @file.file_hash

    begin
      fn = params[:file][:filename]
      params[:file][:tempfile].rewind
      data = params[:file][:tempfile].read

      # Replace file
      @file.replace(fn, data)
      @file.save

    rescue => e
      flash :error, t(:'system/files/inspect/replace/upload_exception', :err => e)
      return redirect to("/system/files/#{@file.file_id}")
    end
    
    begin
      # Delete old file
      old_dirname = File.join(ReConnect.app_config["file-storage-dir"], old_digest[0..1])
      old_filepath = File.join(old_dirname, old_digest)
      File.delete(old_filepath)
      
    rescue => e
      flash :error, t(:'system/files/inspect/replace/unlink_exception', :err => e)
      return redirect to("/system/files/#{@file.file_id}")
    end

    flash :success, t(:'system/files/inspect/replace/success')
    return redirect to("/system/files/#{@file.file_id}")
  end
end
