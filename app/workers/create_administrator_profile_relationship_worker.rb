class ReConnect::Workers::CreateAdministratorProfileRelationshipWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(true)

    admin_pid = ReConnect.app_config['admin-profile-id'].to_i
    if admin_pid.nil? || admin_pid.zero?
      logger.warn("No admin profile ID is configured - please set the 'admin-profile-id' configuration key")
      return
    end

    admin_profile = ReConnect::Models::Penpal[admin_pid]
    unless admin_profile
      logger.warn("The configured admin profile ID (#{admin_pid}) does not exist as a penpal, aborting.")
      return
    end

    relationship_message = (
      "This relationship was created automatically by " +
      "CreateAdministratorProfileRelationshipWorker with job ID " +
      "#{self.jid} at #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}."
    )

    total = ReConnect::Models::Penpal.where(:is_incarcerated => true).count
    logger.info("Checking #{total} penpals...")

    count = {:ok => 0, :created => 0}
    ReConnect::Models::Penpal.where(:is_incarcerated => true).each do |pp|
      count[:ok] += 1
      logger.info("Checked #{count[:ok]} of #{total}") if (count[:ok] % 10) == 0

      # find relationship, continue if it exists
      r = ReConnect::Models::PenpalRelationship.find_for_penpals(pp.id, admin_pid)
      next if r

      # create relationship
      r = ReConnect::Models::PenpalRelationship.new({
        :penpal_one => admin_pid,
        :penpal_two => pp.id,
        :email_approved => true,
        :email_approved_by_id => nil,
        :confirmed => true,
      })

      r.save # to get ID
      r.encrypt(:notes, relationship_message)
      r.save

      # inc
      count[:created] += 1
    end

    logger.info("Checked #{count[:ok]} incarcerated penpals, created #{count[:created]} relationships.")
  end
end
