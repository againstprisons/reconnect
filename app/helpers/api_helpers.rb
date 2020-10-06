module ReConnect::Helpers::ApiHelpers
  def valid_api_token?
    token = request.params['token']&.strip&.downcase
    model = ReConnect::Models::Token.where(token: token, use: 'apikey', valid: true).first
    return false unless model

    model.check_validity!
  end

  def api_json(data)
    content_type 'application/json'
    JSON.generate(data)
  end
end
