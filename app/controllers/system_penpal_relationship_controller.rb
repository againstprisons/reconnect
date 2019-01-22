class ReConnect::Controllers::SystemPenpalRelationshipController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"

  def index(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one = penpal_view_data(@penpal_one) if @penpal_one
    @penpal_one_name = @penpal_one&.key?(:name) ? @penpal_one[:name] : "(unknown)"

    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two = penpal_view_data(@penpal_two) if @penpal_two
    @penpal_two_name = @penpal_two&.key?(:name) ? @penpal_two[:name] : "(unknown)"

    @title = t(:'system/penpal/relationships/title', :one_name => @penpal_one_name, :two_name => @penpal_two_name)

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/relationship/index', :layout => false, :locals => {
        :title => @title,
        :relationship => @relationship,
        :penpal_one => @penpal_one,
        :penpal_two => @penpal_two,
      })
    end
  end
end
