class ReConnect::Controllers::SystemPenpalAddressBookController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @title = t(:'system/penpal/address_book/title')

    penpals_by_status = {}
    ReConnect::Models::Penpal.where(:is_incarcerated => true).each do |pp|
      pp_d = penpal_view_data(pp)
      relationships = pp.relationships.map do |r|
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
          :link => url("/system/penpal/relationship/#{r.id}"),
          :other_party_name => other_party_name,
        }
      end.compact

      penpals_by_status[pp_d[:status]] ||= []
      penpals_by_status[pp_d[:status]] << {
        :obj => pp,
        :pp_d => pp_d,
        :relationships => relationships,
      }
    end

    @pp_statuses = ReConnect.app_config['penpal-statuses'].map do |status|
      [status, penpals_by_status[status] || []]
    end

    haml(:'system/penpal/address_book/index', :locals => {
      :title => @title,
      :pp_statuses => @pp_statuses,
    })
  end
end
