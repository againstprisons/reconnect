module ReConnect::Helpers::SystemPenpalHelpers
  def penpal_view_data(pp)
    data = {
      :id => pp.id,
      :name => pp.get_name,
      :is_incarcerated => pp.is_incarcerated,
    }

    data[:display_fields] = [
      [t(:'name'), data[:name]],
      [t(:'penpal_id'), data[:id]],
      [t(:'is_incarcerated'), data[:is_incarcerated] ? 'yes' : 'no'],
    ]

    data[:user_id] = pp.user.id if pp.user

    if pp.is_incarcerated
      prisoner_number = pp.decrypt(:prisoner_number)&.strip
      prisoner_number = "(unknown)" if prisoner_number.nil? || prisoner_number == ""
      data[:prisoner_number] = prisoner_number 
      data[:display_fields] << [t(:'prisoner_number'), prisoner_number]

      address = pp.decrypt(:address)
        &.split("\n")
        &.map(&:strip)
        &.join(" / ")
      address = "(unknown)" if address.nil? || address == ""
      data[:address] = address
      data[:display_fields] << [t(:'address'), address]
    end

    data
  end
end
