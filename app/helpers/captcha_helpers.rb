module ReConnect::Helpers::CaptchaHelpers
  def captcha_enabled
    ReConnect.app_config['captcha-type'] != 'none'
  end

  def captcha_generate
    case ReConnect.app_config['captcha-type']
    when 'smolcaptcha'
      req_opts = {
        method: :post,
        body: {
          client: ReConnect.app_config['captcha-smolcaptcha-clientid'],
        },
      }

      api_url = Addressable::URI.parse(ReConnect.app_config['captcha-smolcaptcha-baseurl'])
      api_url += '/api/generate'

      response = Typhoeus::Request.new(api_url.to_s, req_opts).run
      return nil unless response.success?
      c_token = response.body.strip

      c_image = Addressable::URI.parse(ReConnect.app_config['captcha-smolcaptcha-baseurl'])
      c_image += "/render/#{c_token}"

      {
        type: 'smolcaptcha',
        token: c_token,
        url_image: c_image,
        url_audio: nil,
      }

    else
      nil
    end
  end

  def captcha_render(c_data)
    return "" unless c_data.is_a?(Hash)

    case c_data[:type]
    when 'smolcaptcha'
      haml :'helpers/captcha/smolcaptcha', layout: false, locals: { c_data: c_data }

    else
      ""
    end
  end

  def captcha_verify(c_data, result)
    return false unless c_data.is_a?(Hash)

    case c_data[:type]
    when 'smolcaptcha'
      req_opts = {
        method: :post,
        body: {
          client: ReConnect.app_config['captcha-smolcaptcha-clientid'],
          captcha: c_data[:token],
          result: result,
        },
      }

      api_url = Addressable::URI.parse(ReConnect.app_config['captcha-smolcaptcha-baseurl'])
      api_url += '/api/verify'

      response = Typhoeus::Request.new(api_url.to_s, req_opts).run
      return false unless response.success?
      return false unless response.body.strip == 'ok'

      true

    else
      false
    end
  end
end
