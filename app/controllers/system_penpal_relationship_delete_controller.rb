class ReConnect::Controllers::SystemPenpalRelationshipDeleteController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:relationship")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one&.get_name
    @penpal_one_name = "(unknown)" unless @penpal_one_name

    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two&.get_name
    @penpal_two_name = "(unknown)" unless @penpal_two_name

    @title = t(:'system/penpal/relationship/delete/title')

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/relationship/delete', :layout => false, :locals => {
          :title => @title,
          :relationship => @relationship,
          :penpal_one => @penpal_one,
          :penpal_one_name => @penpal_one_name,
          :penpal_two => @penpal_two,
          :penpal_two_name => @penpal_two_name,
        })
      end
    end

    if request.params["confirm"]&.strip&.downcase != "on"
      flash :error, t(:'system/penpal/relationship/delete/confirm_not_checked')
      return redirect request.path
    end

    @relationship.delete!

    flash :success, t(:'system/penpal/relationship/delete/success')
    return redirect "/system/penpal"
  end
end
