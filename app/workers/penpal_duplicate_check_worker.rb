class ReConnect::Workers::PenpalDuplicateCheckWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    prisoner_numbers = {}
    total = ReConnect::Models::Penpal.where(:is_incarcerated => true).count
    logger.info("Checking #{total} penpals for PRN duplicates...")

    count = 0
    ReConnect::Models::Penpal.where(:is_incarcerated => true).each do |pp|
      count += 1
      logger.info("Checked #{count} of #{total}") if (count % 10) == 0

      next if pp.prisoner_number.nil?
      next if pp.prisoner_number.empty?

      prn = pp.decrypt(:prisoner_number)&.strip&.downcase
      next if prn.nil?
      next if prn.empty?
      next if prn == '(unknown)'

      prisoner_numbers[prn] ||= []
      prisoner_numbers[prn] << pp.id
    end

    logger.info("Unique PRNs: #{prisoner_numbers.keys.count}")

    prisoner_numbers.keys.each do |prn|
      # create index for the prisoner number so that we can search for the
      # duplicate object, if one exists already
      idx = ReConnect::Models::PenpalDuplicate.create_index(prn.to_s)

      if prisoner_numbers[prn].length > 1
        # is duplicate
        logger.info("Duplicate PRN #{prn}: penpal IDs: #{prisoner_numbers[prn].join(', ')}")

        dup = ReConnect::Models::PenpalDuplicate.find_or_create(:prisoner_number_idx => idx)
        dup.save
        dup.encrypt(:prisoner_number, prn.to_s)
        dup.encrypt(:duplicate_ids, prisoner_numbers[prn].join(','))
        dup.save

        logger.info("Duplicate PRN #{prn}: duplicate created with ID #{dup.id}")
      else
        # not a duplicate
        ReConnect::Models::PenpalDuplicate.where(:prisoner_number_idx => idx).delete
      end
    end
  end
end
