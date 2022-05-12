class ReConnect::Workers::EmailQueueSendWorker
  include Sidekiq::Worker

  # XXX: The way emails work in re:connect right now is horrible and fragile,
  # and is going to be completely rewritten _very_ soon.

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    queue_ids = ReConnect::Models::EmailQueue
      .select(:id, :queue_status)
      .where(queue_status: 'queued')
      .map(&:id)

    logger.info("Starting with #{queue_ids.count} in queue")

    queue_ids.each do |qmid|
      qm = ReConnect::Models::EmailQueue[qmid]
      next unless qm.queue_status = 'queued'
      qm.update(queue_status: 'sending')
      logger.info("Message #{qm.id}: starting send")

      begin
        chunks = qm.generate_messages_chunked
        logger.info("Message #{qm.id}: chunk count #{chunks.count}")

        chunks.each_index do |i|
          logger.info("Message #{qm.id}: sending chunk #{i}")
          chunks[i].deliver!
        end

        qm.update(queue_status: 'sent')
        logger.info("Message #{qm.id}: sent!")

      rescue => e
        qm.update(queue_status: 'error')

        errmsg = "Message #{qm.id}: errored - #{e.class.name}: #{e}\n"
        errmsg += "Traceback: #{e.traceback}" if e.respond_to?(:traceback)
        logger.error(errmsg.strip)
      end
    end
  end
end
