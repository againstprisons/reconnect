class ReConnect::Workers::EmailQueueMessageSendWorker
  include Sidekiq::Worker

  def perform(qmid)
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(force: true)

    qm = ReConnect::Models::EmailQueue[qmid]
    return logger.error("Message #{qmid}: unknown message!?") unless qm
    return logger.error("Message #{qmid}: not 'allocated' but #{qm.queue_status.inspect}") unless qm.queue_status == 'allocated'
    qm.update(queue_status: 'sending')
    logger.info("Message #{qmid}: starting send")

    begin
      chunks = qm.generate_messages_chunked
      chunks.each_index do |i|
        logger.info("Message #{qmid}: sending #{i} of #{chunks.count}")
        begin
          chunks[i].deliver
        rescue => e
          logger.warn("Message #{qmid}: chunk #{i} failed: #{e.class.name}: #{e}")
        end
      end

      qm.update(queue_status: 'sent')
      logger.info("Message #{qmid}: complete :)")

    rescue => e
      qm.update(queue_status: 'error')

      errmsg = "Message #{qmid}: errored - #{e.class.name}: #{e}\n"
      errmsg += "Traceback: #{e.traceback}" if e.respond_to?(:traceback)
      logger.error(errmsg.strip)
    end
  end
end
