class ReConnect::Workers::CorrespondenceCardUpdateWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    helpers = Class.new do
      extend ReConnect::Helpers::SystemPenpalSearchHelpers
    end

    ReConnect.app_config['correspondence-card-instances'].each do |instance_name, instance|
      next logger.info("#{instance_name.inspect} - disabled, skipping") if instance["disabled"]
      logger.info("#{instance_name.inspect} - start processing")

      # Search for penpals matching our statuses
      penpal_ids = []
      instance["statuses"].each do |status|
        penpal_ids << helpers.penpal_search_perform("all status:#{status.inspect}")
      end
      penpal_ids = penpal_ids.flatten.compact.uniq
      logger.info("#{instance_name.inspect} - #{penpal_ids.count} penpal(s)")

      # For each penpal, check that they exist in the card count table
      penpal_ids.each do |ppid|
        cobj = ReConnect::Models::HolidayCardCount.find_or_create({
          penpal_id: ppid,
          card_instance: instance_name
        }).save

        crel = cobj.get_relationship
        unless crel
          crel = ReConnect::Models::PenpalRelationship.new({
            penpal_one: ppid,
            penpal_two: instance["penpal_id"],
            card_instance: instance_name,
            confirmed: true,
          }).save
        end
      end
    end
  end
end
