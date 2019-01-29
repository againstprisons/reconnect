class ReConnect::Controllers::SystemPenpalEditController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name
    @pp_data = penpal_view_data(@penpal)

    @user = nil
    @user = @penpal.user unless @penpal.user_id.nil?

    if @user
      flash :warning, t(:'system/penpal/edit/associated_user')
      return redirect back
    end

    @title = t(:'system/penpal/edit/title', :name => @name, :id => @penpal.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/edit', :layout => false, :locals => {
          :title => @title,
          :penpal => @penpal,
          :pp_data => @pp_data,
          :name => @name,
          :user => @user,
        })
      end
    end

    pp_name = request.params["name"]&.strip
    pp_prisoner_number = request.params["prisoner_number"]&.strip
    pp_address = request.params["address"]&.strip

    if pp_name.nil? || pp_name == ""
      flash :error, t(:'system/penpal/edit/name_required')
      return redirect request.path
    end

    @penpal.encrypt(:name, pp_name)
    @penpal.encrypt(:prisoner_number, pp_prisoner_number)
    @penpal.encrypt(:address, pp_address)
    @penpal.is_incarcerated = request.params["is_incarcerated"]&.strip&.downcase == "on"
    @penpal.save

    flash :success, t(:'system/penpal/edit/success')
    return redirect request.path
  end
end