class ReConnect::Workers::CorrespondenceCardQueueGenerateWorker
  include Sidekiq::Worker

  def perform
    query = ReConnect::Models::Correspondence
      .select(:id, :card_status)
      .where(card_status: 'ready')

    logger.info("#{query.count} waiting to be generated, getting up to 10")

    ids = query.limit(10).map(&:id)
    ids.each do |ccid|
      ReConnect::Workers::CorrespondenceCardGenerateWorker.perform_async(ccid)
    end
  end
end
