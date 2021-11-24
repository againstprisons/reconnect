class ReConnect::Models::HolidayCardCount < Sequel::Model(:correspondence_card_count)
  def get_relationship
    instance = ReConnect.app_config['correspondence-card-instances'][self.card_instance]
    return nil unless instance

    pp_prisoner = ReConnect::Models::Penpal[self.penpal_id]
    pp_instance = ReConnect::Models::Penpal[instance["penpal_id"]]

    ReConnect::Models::PenpalRelationship.find_for_penpals(pp_prisoner, pp_instance)
  end
end
