module ReConnect::Helpers::SystemPenpalHelpers
  def penpal_view_data(pp)
    d = {
      :id => pp.id,
      :name => pp.get_name,
      :is_incarcerated => pp.is_incarcerated,
    }

    if pp.is_incarcerated
      prisoner_number = pp.decrypt(:prisoner_number)&.strip
      prisoner_number = "(unknown)" if prisoner_number.nil? || prisoner_number == ""
      d[:prisoner_number] = prisoner_number 

      address = pp.decrypt(:address)
        &.split("\n")
        &.map(&:strip)
        &.join(" / ")
      address = "(unknown)" if address.nil? || address == ""
      d[:address] = address
    end

    if pp.user
      d[:user] = {
        :id => pp.user.id,
      }
    end

    d
  end
end
