class ReConnect::Controllers::SystemFilesInspectController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/download", :method => :download
  add_route :get, "/delete", :method => :delete
  add_route :post, "/delete", :method => :delete

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
end
