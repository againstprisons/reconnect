class ReConnect::Workers::FilterRefreshWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(true)

    # enable maintenance mode
    logger.info("Enabling maintenance mode")
    maint_cfg = ReConnect::Models::Config.where(:key => 'maintenance').first
    unless maint_cfg
      maint_cfg = ReConnect::Models::Config.new(:key => 'maintenance', :type => 'bool', :value => 'no')
    end
    maint_enabled = maint_cfg.value == 'yes'
    maint_cfg.value = 'yes'
    maint_cfg.save

    # penpal filters
    logger.info("Refreshing penpal filters...")
    pp_count = {:penpal => 0, :filters => 0}
    ReConnect::Models::Penpal.each do |pp|
      ReConnect::Models::PenpalFilter.clear_filters_for(pp)
      filters = ReConnect::Models::PenpalFilter.create_filters_for(pp)

      pp_count[:penpal] += 1
      pp_count[:filters] += filters.length
    end

    logger.info("Generated #{pp_count[:filters]} filters for #{pp_count[:penpal]} penpals.")

    # disable maintenance mode if it wasn't already enabled
    if maint_enabled
      logger.info("Not disabling maintenance mode as it was enabled when worker started")
    else
      logger.info("Disabling maintenance mode")
      maint_cfg.value = 'no'
      maint_cfg.save
    end
  end
end
