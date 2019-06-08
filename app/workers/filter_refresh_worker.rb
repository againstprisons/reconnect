class ReConnect::Workers::FilterRefreshWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(true)

    ###
    # enable maintenance mode
    ###

    logger.info("Enabling maintenance mode")
    maint_cfg = ReConnect::Models::Config.where(:key => 'maintenance').first
    unless maint_cfg
      maint_cfg = ReConnect::Models::Config.new(:key => 'maintenance', :type => 'bool', :value => 'no')
    end
    maint_enabled = maint_cfg.value == 'yes'
    maint_cfg.value = 'yes'
    maint_cfg.save

    ###
    # penpal filters
    ###

    logger.info("Refreshing penpal filters...")

    pp_count = {:penpal => 0, :filters => 0}
    ReConnect::Models::Penpal.each do |pp|
      if pp_count[:penpal] % 10 == 0
        logger.info("Refreshing: processed #{pp_count[:penpal]} so far")
      end

      begin
        ReConnect::Models::PenpalFilter.clear_filters_for(pp)
        filters = ReConnect::Models::PenpalFilter.create_filters_for(pp)
        pp_count[:filters] += filters.length
      rescue => e
        logger.warn("Refreshing failed for penpal ID #{pp.id}: #{e.class.name}: #{e.message}")
      end

      pp_count[:penpal] += 1
    end

    logger.info("Generated #{pp_count[:filters]} filters for #{pp_count[:penpal]} penpals.")

    ###
    # fix `sent` flag on correspondence for inside-to-outside correspondence
    ###

    logger.info("Fixing correspondence sent flag for inside-to-outside correspondence...")

    co_count = {:co => 0, :fixed => 0}
    ReConnect::Models::Correspondence.where(:sent => 'no').each do |c|
      if co_count[:co] % 10 == 0
        logger.info("Fixing sent flag: checked #{co_count[:co]} correspondence entries so far")
      end

      begin
        pp = ReConnect::Models::Penpal[c.receiving_penpal]
        if pp.is_incarcerated == false
          c.sent = "to_outside"
          c.save

          co_count[:fixed] += 1
        end
      rescue => e
        logger.warn("Fixing sent flag failed for correspondence ID #{c.id}: #{e.class.name}: #{e.message}")
      end

      co_count[:co] += 1
    end

    logger.info("Fixed sent flag for #{co_count[:fixed]} entries, checked #{co_count[:co]} entries.")

    ###
    # disable maintenance mode if it wasn't already enabled
    ####

    if maint_enabled
      logger.info("Not disabling maintenance mode as it was enabled when worker started")
    else
      logger.info("Disabling maintenance mode")
      maint_cfg.value = 'no'
      maint_cfg.save
    end
  end
end
