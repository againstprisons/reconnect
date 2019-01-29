class ReConnect::Workers::EmailQueueSendWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?

    ReConnect::Models::EmailQueue.where(:queue_status => 'queued').all.each do |qm|
      # save state as 'sending'
      qm.queue_status = 'sending'
      qm.save

      begin
        qm.generate_messages_chunked.each do |message|
          message.deliver!
        end

        qm.queue_status = 'sent'
        qm.save
      rescue => e
        puts "Error while sending message #{qm.id}: #{e.class.name}: #{e}"
        puts e.traceback if e.respond_to?(:traceback)

        qm.queue_status = 'error'
        qm.save
      end
    end
  end
end
