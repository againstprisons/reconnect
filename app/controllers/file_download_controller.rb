class ReConnect::Controllers::FileDownloadController < ReConnect::Controllers::ApplicationController
  add_route :get, "/:fileid/:token"

  def index(fid, token)
    return halt 404 unless logged_in?
    @user = current_user

    @token = ReConnect::Models::Token.where(:token => token).first
    return halt 404 unless @token
    return halt 404 unless @token.valid
    return halt 404 unless @token.use == "file_download"
    return halt 404 unless @token.user_id == current_user.id
    return halt 404 if @token.check_expiry!

    @file = ReConnect::Models::File.where(:file_id => fid).first
    return halt 404 unless @file
    return halt 404 unless @token.extra_data == @file.file_id

    data = @file.decrypt_file

    content_type @file.mime_type
    attachment @file.generate_fn
    return data
  end
end
