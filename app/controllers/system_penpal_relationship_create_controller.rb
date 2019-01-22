class ReConnect::Controllers::SystemPenpalRelationshipCreateController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index()
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:relationship")

    @title = t(:'system/penpal/relationships/create/title')

    penpal_one_id = request.params["penpal_one"]&.strip.to_i
    penpal_two_id = request.params["penpal_two"]&.strip.to_i

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/relationship/create', :layout => false, :locals => {
          :title => @title,
          :penpal_one_id => penpal_one_id,
          :penpal_two_id => penpal_two_id,
        })
      end
    end

    @penpal_one = ReConnect::Models::Penpal[penpal_one_id]
    @penpal_two = ReConnect::Models::Penpal[penpal_two_id]
    if @penpal_one.nil? || @penpal_two.nil?
      flash :error, t(:'system/penpal/relationships/create/invalid_penpals')
      return redirect back
    end

    if ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal_one, @penpal_two)
      flash :error, t(:'system/penpal/relationships/create/relationship_exists')
      return redirect back
    end

    @relationship = ReConnect::Models::PenpalRelationship.new
    @relationship.penpal_one = @penpal_one.id
    @relationship.penpal_two = @penpal_two.id
    @relationship.save

    flash :success, t(:'system/penpal/relationships/create/success')
    redirect to("/system/penpal/relationship/#{@relationship.id}")
  end
end
