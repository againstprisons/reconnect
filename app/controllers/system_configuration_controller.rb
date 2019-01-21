class ReConnect::Controllers::SystemConfigurationController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/toggle", :method => :toggle
  add_route :post, "/refresh", :method => :refresh

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:access")

    @title = t(:'system/configuration/title')

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/configuration/index', :layout => false, :locals => {
        :title => @title,
        :is_maintenance => is_maintenance?(),
        :signups_enabled => signups_enabled?(),
      })
    end
  end

  def toggle
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:access")

    key = request.params["key"]&.strip&.downcase
    if key.nil? || key == ""
      flash :error, t(:required_field_missing)
      return redirect to("/system/configuration")
    end

    cfg = ReConnect::Models::Config.where(:key => key).first
    unless cfg
      cfg = ReConnect::Models::Config.new(:key => key, :type => 'bool', :value => 'no')
    end

    if cfg.type != 'bool'
      flash :error, t(:'system/configuration/quick_toggle/key_not_bool')
      return redirect to("/system/configuration")
    end

    cfg.value = (cfg.value == 'yes' ? 'no' : 'yes')
    cfg.save

    flash :success, t(:'system/configuration/quick_toggle/toggled', :key => key, :value => cfg.value)
    redirect to("/system/configuration")
  end

  def refresh
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:refresh")

    unless ReConnect.app_config_refresh_pending
      flash :warning, t(:'system/configuration/refresh_global_config/not_required')
      return redirect to("/system/configuration")
    end

    # enable maintenance mode
    maint_cfg = ReConnect::Models::Config.where(:key => 'maintenance').first
    unless maint_cfg
      maint_cfg = ReConnect::Models::Config.new(:key => 'maintenance', :type => 'bool', :value => 'no')
    end
    maint_enabled = maint_cfg.value == 'yes'
    maint_cfg.value = 'yes'
    maint_cfg.save

    # refresh
    ReConnect.app_config_refresh

    # disable maintenance mode if it wasn't already enabled
    unless maint_enabled
      maint_cfg.value = 'no'
      maint_cfg.save
    end

    flash :success, t(:'system/configuration/refresh_global_config/success')
    redirect to("/system/configuration")
  end
end
