class ReConnect::Controllers::FileDownloadController < ReConnect::Controllers::ApplicationController
  add_route :get, "/:fileid/:token"

  def index(fid, token)
    @token = ReConnect::Models::Token.where(:token => token, :use => 'file_download').first
    return halt 404 unless @token
    return halt 404 unless @token.check_validity!

    if @token.user_id
      return halt 404 unless @token.user_id == current_user&.id
    end

    @file = ReConnect::Models::File.where(:file_id => fid).first
    return halt 404 unless @file
    return halt 404 unless @token.extra_data == @file.file_id

    @token.invalidate!

    data = @file.decrypt_file

    content_type @file.mime_type
    attachment @file.generate_fn
    return data
  end
end
