class ReConnect::Workers::AddressBookGenerateWorker
  include Sidekiq::Worker

  class LocalHelpers
    def self.pretty_time(time)
      a = (Time.now - time).to_i
      future = a.negative?
      a = a.abs

      relative = nil
      case a
      when 0..59
        relative = "#{a} seconds"
      when 60..(3600 - 1)
        relative = "#{(a / 60).to_i} minutes"
      when 3600..((3600 * 24) - 1)
        relative = "#{(a / 3600).to_i} hours"
      when (3600 * 24)..(3600 * 24 * 30)
        relative = "#{(a / (3600 * 24)).to_i} days"
      else
        return time.strftime("%Y-%m-%d %H:%M")
      end

      return "in #{relative}" if future
      "#{relative} ago"
    end

    # inlined from EmailTemplateHelpers#new_tilt_template_from_fn with adjusted paths
    def self.new_tilt_template_from_fn(filename)
      path = File.join(ReConnect.root, "app", "views", filename)

      if ReConnect.theme_dir
        theme_path = File.join(ReConnect.theme_dir, "views", filename)
        if File.file?(theme_path)
          path = theme_path
        end
      end

      return nil unless File.file?(path)
      Tilt::ERBTemplate.new(path)
    end

    # this is mostly an inlined version of SystemPenpalHelpers#penpal_view_data
    # with some extra stuff like penpal relationships 
    def self.penpal_data(pp, prisons)
      data = {
        :id => pp.id,
        :flags => [],
      }

      # name
      data[:name_a] = name_a = pp.get_name
      name = name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
      name = "(unknown)" if name.nil? || name&.strip&.empty?
      data[:name] = name
      data[:pseudonym] = pp.get_pseudonym 

      # prisoner number
      prisoner_number = pp.decrypt(:prisoner_number)&.strip
      prisoner_number = nil if prisoner_number.empty?
      data[:prisoner_number] = prisoner_number || '(unknown)'

      # birthday
      birthday = pp.decrypt(:birthday)&.strip&.downcase
      data[:birthday] = Chronic.parse(birthday, :guess => true)

      # status
      status = pp.decrypt(:status)&.strip
      if !(ReConnect.app_config['penpal-statuses'].include?(status))
        status = ReConnect.app_config['penpal-status-default']
      end
      data[:status] = status

      # status override
      if ReConnect.app_config["penpal-allow-status-override"] || pp.status_override
        data[:status_override] = pp.status_override
        data[:flags] << "no automatic status changes" if pp.status_override
      end

      # advocacy
      data[:is_advocacy] = pp.is_advocacy
      data[:flags] << "advocacy case" if pp.is_advocacy

      # correspondence guide sent
      data[:correspondence_guide_sent] = pp.correspondence_guide_sent
      data[:flags] << "correspondence guide not sent" unless pp.correspondence_guide_sent

      # expected release date
      release_date = pp.decrypt(:expected_release_date)&.strip&.downcase
      data[:release_date] = Chronic.parse(release_date, :guess => true)

      # creation
      data[:creation] = pp.creation

      # get last correspondence
      begin
        data[:last_correspondence] = nil
        last = ReConnect::Models::Correspondence
          .where(:sending_penpal => pp.id)
          .order(Sequel.desc(:creation))
          .first

        if last
          data[:last_correspondence] = {
            :model => last,
            :creation => last.creation,
            :creation_pretty => [
              last.creation.strftime("%Y-%m-%d %H:%M"),
              "(#{pretty_time(last.creation)})",
            ].join(" "),
          }
        end
      end

      # prison info
      begin
        prison_id = pp.decrypt(:prison_id).to_i
        prison = prisons[prison_id.to_s]
        if prison
          data[:prison] = {
            name: prison,
            id: prison_id,
          }
        end
      end

      # relationships
      data[:relationships] = pp.relationships.map do |r|
        other_party = r.penpal_one
        other_party = r.penpal_two if other_party == pp.id
        other_party = ReConnect::Models::Penpal[other_party]
        next nil unless other_party

        # ignore administration profile
        next nil if other_party.id == ReConnect.app_config['admin-profile-id']&.to_i

        other_party_name = other_party.get_name
        other_party_name = other_party_name.map{|x| x == "" ? nil : x}.compact.join(" ")
        other_party_pseudonym = other_party.get_pseudonym
        other_party_name = "#{other_party_name} (#{other_party_pseudonym})" if other_party_pseudonym

        {
          :id => r.id,
          :other_party_id => other_party.id,
          :other_party_name => other_party_name,
        }
      end.compact

      data
    end
  end
  
  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(force: true)

    prisons = ReConnect::Models::Prison.map {|pr| [pr.id.to_s, pr.decrypt(:name)]}.to_h
    penpals = ReConnect::Models::Penpal.where(is_incarcerated: true).map do |pp|
      LocalHelpers.penpal_data(pp, prisons)
    end

    # group by status
    by_status = {}
    penpals.each do |pp|
      by_status[pp[:status]] ||= []
      by_status[pp[:status]] << pp
    end

    viewdata = OpenStruct.new({
      ts: Time.now,
      penpals: by_status.to_a.sort_by {|a| ReConnect.app_config['penpal-statuses'].index(a.first) },
    })

    # render to html
    tpl = LocalHelpers.new_tilt_template_from_fn("address_book.erb")
    html = tpl.render(viewdata)

    # save to encrypted file
    file = ReConnect::Models::File.upload(html, filename: "reconnect-address-book-#{Time.now.to_i}.html", mime_type: 'text/html;x-reconnect-type=address-book')
    logger.info("saved with file ID #{file.file_id}")
  end
end
