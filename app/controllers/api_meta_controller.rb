class ReConnect::Controllers::ApiMetaController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    data = {
      site_name: ReConnect.app_config['site-name'],
      org_name: ReConnect.app_config['org-name'],
      base_url: ReConnect.app_config['base-url'],
    }

    if ReConnect.app_config['display-version']
      data[:version] = ReConnect.version
    end

    api_json(data)
  end
end
