module ReConnect::Helpers::SystemPenpalHelpers
  def penpal_view_data(pp)
    name_a = pp.get_name
    name = name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    name = "(unknown)" if name.nil? || name&.strip&.empty?

    data = {
      :id => pp.id,
      :name => name,
      :name_a => name_a,
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
      prisoner_number = "(unknown)" if prisoner_number.nil? || prisoner_number.empty?
      data[:prisoner_number] = prisoner_number 
      data[:display_fields] << [t(:'prisoner_number'), prisoner_number]

=begin
      address = pp.decrypt(:address)&.split("\n")&.map(&:strip)
      unless address.nil? || address.empty?
        data[:address] = address&.join("\n")
        data[:display_fields] << [t(:'address'), address&.join(" / ")]
      end
=end

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

    data
  end
end
