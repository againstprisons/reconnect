class ReConnect::Controllers::SystemIndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:access")

    @title = t(:'system/title')
    @to_action = ReConnect::Models::Correspondence
      .where(:sent => 'no')
      .map(&:get_data)
      .reject{|x| x[:actioned]}

    @duplicates = ReConnect::Models::PenpalDuplicate.map do |dup|
      prn = dup.decrypt(:prisoner_number)
      penpals = dup.decrypt(:duplicate_ids).split(',').map(&:to_i).map do |pp|
        pp = ReConnect::Models::Penpal[pp]
        next nil unless pp

        name = pp.get_name
        name = name.map{|x| x == "" ? nil : x}.compact.join(" ")
        pseudonym = pp.get_pseudonym
        pseudonym = nil if pseudonym&.empty?

        {
          :name => name,
          :pseudonym => pseudonym,
          :id => pp.id,
        }
      end.compact

      {
        :prisoner_number => prn,
        :penpals => penpals,
      }
    end

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/index', :layout => false, :locals => {
        :title => @title,
        :to_action => @to_action,
        :duplicates => @duplicates,
        :counts => {
          :penpals => ReConnect::Models::Penpal.count,
          :relationships => ReConnect::Models::PenpalRelationship.count,
          :correspondence => ReConnect::Models::Correspondence.count,
        },
      })
    end
  end
end
