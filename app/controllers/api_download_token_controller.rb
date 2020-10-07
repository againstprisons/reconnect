class ReConnect::Controllers::ApiDownloadTokenController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @file_id = request.params['fileid']&.strip&.downcase
    @file = ReConnect::Models::File.where(file_id: @file_id).first
    unless @file
      return api_json({
        success: false,
        message: 'no file with that ID',
      })
    end

    @token = @file.generate_download_token(nil)

    @download_url = Addressable::URI.parse(ReConnect.app_config['base-url'])
    @download_url += "/filedl/#{@file.file_id}/#{@token.token}"

    api_json({
      token: @token.token,
      url: @download_url.to_s,
    })
  end
end
