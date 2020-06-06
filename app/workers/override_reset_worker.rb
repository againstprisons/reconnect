class ReConnect::Workers::OverrideResetWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    if !ReConnect.app_config['penpal-allow-status-override']
      logger.info("`penpal-allow-status-override` is disabled, checking for penpals with flag set")
      ds = ReConnect::Models::Penpal.where(status_override: true)
      if ds.count.positive?
        logger.info("#{ds.count} penpals with flag set, resetting them all")
        ds.update(status_override: false)
      end
    end
    
    if !ReConnect.app_config['penpal-relationship-allow-archive']
      logger.info("`penpal-relationship-allow-archive` is disabled, checking for relationships with flag set")
      ds = ReConnect::Models::PenpalRelationship.where(status_override: true)
      if ds.count.positive?
        logger.info("#{ds.count} relationships with flag set, resetting them all")
        ds.update(status_override: false)
      end
    end
  end
end
