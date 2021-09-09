class ReConnect::Workers::AccountPurgeWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    logger.info("Looking for users with `purge_at_next_opportunity` set…")
    users = ReConnect::Models::User.where(purge_at_next_opportunity: true).map do |user|
      logger.info("Deleting User[#{user.id}] - #{user.get_name.compact.join(" ")}")
      user.delete!
    end

    logger.info("Purged #{users.count} user(s)")
  end
end
