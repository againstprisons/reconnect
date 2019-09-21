class ReConnect::Controllers::SystemConfigurationController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/toggle", :method => :toggle
  add_route :post, "/refresh", :method => :refresh
  add_route :post, "/create-admin-penpal", :method => :create_admin_penpal

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:access")

    @title = t(:'system/configuration/title')

    admin_pid = ReConnect.app_config['admin-profile-id']&.to_i
    admin_profile_exists = !(admin_pid.nil? || admin_pid.zero?) && !(ReConnect::Models::Penpal[admin_pid].nil?)

    signups_enabled = ReConnect::Models::Config.where(:key => "signups").first&.value == "yes"
    signups_pending = ReConnect.app_config["signups"] != signups_enabled

    quick_toggles = [
      {
        :key => "maintenance",
        :enabled => is_maintenance?(),
        :pending_refresh => false,
        :button_classes => {
          :enable => 'button-error',
          :disable => 'button-primary',
        },
        :text => {
          :enabled => t(:'system/configuration/quick_toggle/maintenance/is_enabled'),
          :disabled => t(:'system/configuration/quick_toggle/maintenance/is_disabled'),
        },
      },
      {
        :key => "signups",
        :enabled => signups_enabled,
        :pending_refresh => signups_pending,
        :button_classes => {
          :enable => 'button-primary',
          :disable => 'button-error',
        },
        :text => {
          :enabled => t(:'system/configuration/quick_toggle/signups/is_enabled'),
          :disabled => t(:'system/configuration/quick_toggle/signups/is_disabled'),
        },
      },
    ]

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/configuration/index', :layout => false, :locals => {
        :title => @title,
        :quick_toggles => quick_toggles,
        :admin_profile_exists => admin_profile_exists,
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

    # push key name to the list of pending refreshes
    if ReConnect::APP_CONFIG_ENTRIES.key?(key) && !(%w[maintenance].include?(key))
      unless ReConnect.app_config_refresh_pending.include?(key)
        ReConnect.app_config_refresh_pending << key
        session[:we_changed_app_config] = true
      end
    end

    # clear signup pending if we're back at the cached state
    if key == "signups" && ReConnect.app_config["signups"] == (cfg.value == 'yes')
      ReConnect.app_config_refresh_pending.delete("signups")
    end

    flash :success, t(:'system/configuration/quick_toggle/toggled', :key => key, :value => cfg.value)
    redirect to("/system/configuration")
  end

  def refresh
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:refresh")

    session.delete(:we_changed_app_config)

    unless ReConnect.app_config_refresh_pending || ReConnect::ServerUtils.app_server_has_multiple_workers?
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
    keys = ReConnect.app_config_refresh

    # disable maintenance mode if it wasn't already enabled
    unless maint_enabled
      maint_cfg.value = 'no'
      maint_cfg.save
    end

    if ReConnect::ServerUtils.app_server_has_multiple_workers?
      flash :success, t(:'system/configuration/refresh_global_config/success_restarting')
      ReConnect::ServerUtils.app_server_restart!
    else
      flash :success, t(:'system/configuration/refresh_global_config/success', :count => keys.count)
    end

    redirect to("/system/configuration")
  end

  def create_admin_penpal
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:admin_penpal")

    # verify admin penpal doesn't already exist
    admin_pid = ReConnect.app_config['admin-profile-id']&.to_i
    if !admin_pid.nil? && !admin_pid.zero? && !(ReConnect::Models::Penpal[admin_pid].nil?)
      return halt 418
    end

    # enable maintenance mode
    maint_cfg = ReConnect::Models::Config.where(:key => 'maintenance').first
    unless maint_cfg
      maint_cfg = ReConnect::Models::Config.new(:key => 'maintenance', :type => 'bool', :value => 'no')
    end
    maint_enabled = maint_cfg.value == 'yes'
    maint_cfg.value = 'yes'
    maint_cfg.save

    # create admin penpal
    admin_penpal = ReConnect::Models::Penpal.new
    admin_penpal.save # get ID
    admin_penpal.encrypt(:first_name, ReConnect.app_config['org-name'])
    admin_penpal.encrypt(:last_name, "Administration Profile")
    admin_penpal.is_incarcerated = false
    admin_penpal.is_advocacy = false
    admin_penpal.correspondence_guide_sent = false
    admin_penpal.creation = Time.now
    admin_penpal.save

    # create filters
    ReConnect::Models::PenpalFilter.create_filters_for(admin_penpal)

    # save profile id to config
    cfg = ReConnect::Models::Config.where(:key => 'admin-profile-id').first
    unless cfg
      cfg = ReConnect::Models::Config.new(:key => 'admin-profile-id', :type => 'number')
    end
    cfg.value = admin_penpal.id.to_s
    cfg.save

    # refresh
    ReConnect.app_config_refresh_pending << 'admin-profile-id'
    ReConnect.app_config_refresh

    # create job to add relationships
    rjobid = ReConnect::Workers::CreateAdministratorProfileRelationshipWorker.perform_async

    # success alert
    flash :success, t(:'system/configuration/create_admin_penpal/success', :rjobid => rjobid)

    # disable maintenance mode if it wasn't already enabled
    unless maint_enabled
      maint_cfg.value = 'no'
      maint_cfg.save
    end

    # do an app restart if we need to
    if ReConnect::ServerUtils.app_server_has_multiple_workers?
      ReConnect::ServerUtils.app_server_restart!
    end

    return redirect url("/system/penpal/#{admin_penpal.id}")
  end
end
