class ReConnect::Controllers::SystemPenpalRelationshipsController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[uid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name

    @relationships = @penpal.relationships.map do |r|
      other_party = r.penpal_one
      other_party = r.penpal_two if other_party == @penpal.id
      other_party = ReConnect::Models::Penpal[other_party]
      next nil unless other_party

      {
        :id => r.id,
        :other_party => {
          :id => other_party.id,
          :name => other_party.get_name,
        }
      }
    end.compact

    @title = t(:'system/penpal/relationships/title', :name => @name, :id => @penpal.id)

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/relationships', :layout => false, :locals => {
        :title => @title,
        :penpal => @penpal,
        :name => @name,
        :relationships => @relationships,
      })
    end
  end
end
