class ReConnect::Controllers::SystemConfigurationSiteOrgNameController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:edit")

    @title = t(:'system/configuration/site_org_name/title')

    site_name_cfg = ReConnect::Models::Config.where(:key => 'site-name').first
    unless site_name_cfg
      site_name_cfg = ReConnect::Models::Config.new(:key => 'site-name', :type => 'text')
    end

    org_name_cfg = ReConnect::Models::Config.where(:key => 'org-name').first
    unless org_name_cfg
      org_name_cfg = ReConnect::Models::Config.new(:key => 'org-name', :type => 'text')
    end

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/configuration/site_org_name', :layout => false, :locals => {
          :title => @title,
          :site_name_cfgval => site_name_cfg.value || ReConnect.app_config["site-name"],
          :org_name_cfgval => org_name_cfg.value || ReConnect.app_config["org-name"],
        })
      end
    end

    old_site_name = site_name_cfg.value
    old_org_name = org_name_cfg.value

    site_name = request.params["site_name"]&.strip
    org_name = request.params["org_name"]&.strip

    if site_name.nil? || site_name == ""
      flash :error, t(:'system/configuration/site_org_name/site_name/missing')
      return redirect request.path
    end

    if org_name.nil? || org_name == ""
      flash :error, t(:'system/configuration/site_org_name/org_name/missing')
      return redirect request.path
    end

    # push site-name to refresh list if it's changed
    if site_name != old_site_name
      site_name_cfg.value = site_name
      site_name_cfg.save

      unless ReConnect.app_config_refresh_pending.include?("site-name")
        ReConnect.app_config_refresh_pending << "site-name"
        session[:we_changed_app_config] = true
      end
    end

    # push org-name to refresh list if it's changed
    if org_name != old_org_name
      org_name_cfg.value = org_name
      org_name_cfg.save

      unless ReConnect.app_config_refresh_pending.include?("org-name")
        ReConnect.app_config_refresh_pending << "org-name"
        session[:we_changed_app_config] = true
      end
    end

    flash :success, t(:'system/configuration/site_org_name/success')
    return redirect request.path
  end
end
