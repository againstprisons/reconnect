class ReConnect::Controllers::SystemPenpalRelationshipCorrespondenceController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"

  def index(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:relationship:correspondence:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_one_name = "(unknown)" if @penpal_one_name.nil? || @penpal_one_name&.strip&.empty?
    @penpal_one_pseudonym = @penpal_one.get_pseudonym

    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_two_name = "(unknown)" if @penpal_two_name.nil? || @penpal_two_name&.strip&.empty?
    @penpal_two_pseudonym = @penpal_two.get_pseudonym

    @title = t(:'system/penpal/relationship/correspondence/title', {
      :one_name => @penpal_one_name,
      :one_pseudonym => @penpal_one_pseudonym,
      :two_name => @penpal_two_name,
      :two_pseudonym => @penpal_two_pseudonym
    })

    @correspondence = ReConnect::Models::Correspondence.find_for_relationship(@relationship).map{|x| x.get_data}.compact

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/relationship/correspondence/index', :layout => false, :locals => {
        :title => @title,
        :relationship => @relationship,
        :penpal_one => @penpal_one,
        :penpal_two => @penpal_two,
        :correspondence => @correspondence,
      })
    end
  end
end
