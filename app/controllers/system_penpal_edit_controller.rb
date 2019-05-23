class ReConnect::Controllers::SystemPenpalEditController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @penpal_name_a = @penpal.get_name
    @penpal_name = @penpal_name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    @pp_data = penpal_view_data(@penpal)
    @prisons = ReConnect::Models::Prison.all.map do |p|
      {
        :id => p.id,
        :name => p.decrypt(:name),
      }
    end

    @user = nil
    @user = @penpal.user unless @penpal.user_id.nil?

    if @user
      flash :warning, t(:'system/penpal/edit/associated_user')
      return redirect back
    end

    @title = t(:'system/penpal/edit/title', :name => @penpal_name, :id => @penpal.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/edit', :layout => false, :locals => {
          :title => @title,
          :penpal => @penpal,
          :pp_data => @pp_data,
          :name => @penpal_name,
          :name_a => @penpal_name_a,
          :user => @user,
          :prisons => @prisons,
        })
      end
    end

    pp_first_name = request.params["first_name"]&.strip
    pp_last_name = request.params["last_name"]&.strip
    if pp_first_name.nil? || pp_first_name&.empty? || pp_last_name.nil? || pp_last_name&.empty?
      flash :error, t(:'system/penpal/edit/name_required')
      return redirect request.path
    end

    @penpal.encrypt(:first_name, pp_first_name)
    @penpal.encrypt(:last_name, pp_last_name)

    pp_prisoner_number = request.params["prisoner_number"]&.strip
    @penpal.encrypt(:prisoner_number, pp_prisoner_number)

    #pp_address = request.params["address"]&.strip
    #@penpal.encrypt(:address, pp_address)

    pp_prison = request.params["prison"]&.strip&.downcase.to_i
    if pp_prison.nil? || pp_prison.zero?
      pp_prison = nil
    else
      pp_prison = ReConnect::Models::Prison[pp_prison]&.id
    end
    @penpal.encrypt(:prison_id, pp_prison)

    @penpal.is_incarcerated = request.params["is_incarcerated"]&.strip&.downcase == "on"
    @penpal.save

    ReConnect::Models::PenpalFilter.clear_filters_for(@penpal)
    ReConnect::Models::PenpalFilter.create_filters_for(@penpal)

    flash :success, t(:'system/penpal/edit/success')
    return redirect request.path
  end
end
