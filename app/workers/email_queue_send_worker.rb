class ReConnect::Workers::EmailQueueSendWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(true)

    messages = ReConnect::Models::EmailQueue.where(:queue_status => 'queued')
    logger.info("Queued message count: #{messages.count}")

    messages.all.each do |qm|
      logger.info("Message #{qm.id}: starting")

      # save state as 'sending'
      qm.queue_status = 'sending'
      qm.save

      begin
        chunks = qm.generate_messages_chunked
        logger.info("Message #{qm.id}: chunk count #{chunks.count}")

        chunks.each_index do |i|
          logger.info("Message #{qm.id}: sending chunk #{i}")
          chunks[i].deliver!
        end

        qm.queue_status = 'sent'
        qm.save

        logger.info("Message #{qm.id}: sent!")

      rescue => e
        qm.queue_status = 'error'
        qm.save

        errmsg = "Message #{qm.id}: errored - #{e.class.name}: #{e}\n"
        errmsg += "Traceback: #{e.traceback}" if e.respond_to?(:traceback)
        logger.error(errmsg)
      end
    end
  end
end
