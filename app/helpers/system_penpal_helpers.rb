module ReConnect::Helpers::SystemPenpalHelpers
  def penpal_view_data(pp)
    data = {
      :id => pp.id,
      :display_fields => [
        [t(:'penpal_id'), pp.id],
      ],
    }

    # name
    data[:name_a] = name_a = pp.get_name
    name = name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    name = "(unknown)" if name.nil? || name&.strip&.empty?
    data[:name] = name
    data[:display_fields] << [t(:'name/first'), name_a.first]
    data[:display_fields] << [t(:'name/middle'), name_a[1]] if name_a.length == 3
    data[:display_fields] << [t(:'name/last'), name_a.last]

    # pseudonym
    data[:pseudonym] = pp.get_pseudonym
    data[:display_fields] << [t(:'pseudonym'), data[:pseudonym]]

    # user ID
    data[:user_id] = pp.user ? pp.user.id : nil
    data[:display_fields] << [t(:'user_id'), pp.user.id] if pp.user

    # email
    data[:email] = pp.user ? pp.user.email : nil

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
        }

        data[:display_fields] << [
          t(:'last_correspondence'),
          [
            last.creation.strftime("%Y-%m-%d %H:%M"),
            "(#{pretty_time(last.creation)})"
          ].join(" "),
        ]
      else
        data[:display_fields] << [
          t(:'last_correspondence'),
          '(none)'
        ]
      end
    end

    # incarcerated status
    data[:is_incarcerated] = pp.is_incarcerated
    data[:display_fields] << [
      t(:'is_incarcerated'),
      data[:is_incarcerated] ? 'yes' : 'no'
    ]

    if pp.is_incarcerated
      # prisoner number
      prisoner_number = pp.decrypt(:prisoner_number)&.strip
      prisoner_number = nil if prisoner_number.empty?
      data[:prisoner_number] = prisoner_number
      data[:display_fields] << [
        t(:'prisoner_number'),
        prisoner_number.nil?() ? '(unknown)' : prisoner_number
      ]

      # birthday
      birthday = pp.decrypt(:birthday)&.strip&.downcase
      data[:birthday] = Chronic.parse(birthday, :guess => true)
      if data[:birthday]
        data[:display_fields] << [t(:'birthday'), data[:birthday].strftime("%Y-%m-%d")]
      end

      # status
      status = pp.decrypt(:status)&.strip
      if !(ReConnect.app_config['penpal-statuses'].include?(status))
        status = ReConnect.app_config['penpal-status-default']
      end
      data[:status] = status
      data[:display_fields] << [t(:'penpal_status'), status]

      # advocacy
      data[:is_advocacy] = pp.is_advocacy
      data[:display_fields] << [t(:'is_advocacy'), pp.is_advocacy ? 'yes' : 'no']

      # correspondence guide sent
      data[:correspondence_guide_sent] = pp.correspondence_guide_sent
      data[:display_fields] << [t(:'correspondence_guide_sent'), pp.correspondence_guide_sent ? 'yes' : 'no']

      # prison info
      begin
        prison = ReConnect::Models::Prison[pp.decrypt(:prison_id).to_i]
        if prison
          data[:prison] = {
            :id => prison.id,
            :name => prison.decrypt(:name),
            :email_address => prison.decrypt(:email_address),
            :address => prison.decrypt(:physical_address),
          }

          data[:display_fields] << [t(:'prison'), data[:prison][:name]]
          data[:display_fields] << [t(:'address'), data[:prison][:address].lines.map(&:strip).join(", ")]
        else
          data[:display_fields] << [t(:'prison'), '(unknown)']
        end
      end

      # expected release date
      release_date = pp.decrypt(:expected_release_date)&.strip&.downcase
      data[:release_date] = Chronic.parse(release_date, :guess => true)
      if data[:release_date]
        data[:display_fields] << [t(:'release_date'), data[:release_date].strftime("%Y-%m-%d")]
      end
    end

    data
  end
end
