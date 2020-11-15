module ReConnect::Helpers::ApiHelpers
  def valid_api_token?
    token = request.params['token']&.strip&.downcase
    model = ReConnect::Models::Token.where(token: token, use: 'apikey', valid: true).first
    return false unless model

    model.check_validity!
  end

  def api_json(data)
    content_type 'application/json'

    unless data.key?(:success) || data.key?('success')
      data[:success] = true
    end

    JSON.generate(data)
  end
end
