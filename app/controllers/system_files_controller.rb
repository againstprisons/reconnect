class ReConnect::Controllers::SystemFilesController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/upload", :method => :upload
  add_route :post, "/inspect-redir", :method => :inspect_redir

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

    @title = t(:'system/files/title')

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/files/index', :layout => false, :locals => {
        :title => @title,
      })
    end
  end

  def upload
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")
    return halt 500 unless params[:file]

    begin
      fn = params[:file][:filename]
      params[:file][:tempfile].rewind
      data = params[:file][:tempfile].read

      obj = ReConnect::Models::File.upload(data, :filename => fn)
      obj.save

    rescue => e
      flash :error, t(:'system/files/upload/exception', :err => e)
      return redirect back
    end

    flash :success, t(:'system/files/upload/success', :id => obj.file_id)
    return redirect to("/system/files/#{obj.file_id}")
  end

  def inspect_redir
    return 404 unless request.params["id"]
    return redirect to("/system/files/#{request.params["id"]}")
  end

  def inspect(fid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

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
end
