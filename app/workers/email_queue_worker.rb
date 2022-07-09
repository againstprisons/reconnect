class ReConnect::Workers::EmailQueueWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?

    ds = ReConnect::Models::EmailQueue
      .select(:id, :queue_status)
      .where(queue_status: 'queued')

    ds.map do |qm|
      next unless qm.queue_status == 'queued'

      qm.update(queue_status: 'allocated')
      jobid = ReConnect::Workers::EmailQueueMessageSendWorker.perform_async(qm.id)
      qm.update(send_job_id: jobid)

      logger.info("Message #{qm.id} send allocated, job #{jobid}")
    end
  end
end
