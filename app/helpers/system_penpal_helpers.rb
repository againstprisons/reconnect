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
    data[:display_fields] << [t(:'name'), name]

    # user ID
    data[:user_id] = pp.user ? pp.user.id : nil
    data[:display_fields] << [t(:'user_id'), pp.user.id] if pp.user


    # incarcerated status
    data[:display_fields] << [
      t(:'is_incarcerated'),
      data[:is_incarcerated] ? 'yes' : 'no'
    ]

    if pp.is_incarcerated
      # prisoner number
      prisoner_number = pp.decrypt(:prisoner_number)&.strip
      prisoner_number = "(unknown)" if prisoner_number.nil? || prisoner_number.empty?
      data[:prisoner_number] = prisoner_number 
      data[:display_fields] << [t(:'prisoner_number'), prisoner_number]

      # prison info
      begin
        prison = ReConnect::Models::Prison[pp.decrypt(:prison_id).to_i]
        if prison
          data[:prison] = {
            :id => prison.id,
            :name => prison.decrypt(:name),
          }

          data[:display_fields] << [t(:'prison'), data[:prison][:name]]
        else
          data[:display_fields] << [t(:'prison'), '(unknown)']
        end
      end
    end

    data
  end
end
