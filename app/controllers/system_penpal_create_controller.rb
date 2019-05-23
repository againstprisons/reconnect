class ReConnect::Controllers::SystemPenpalCreateController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:create")

    @title = t(:'system/penpal/create/title')

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/create', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    pp_first_name = request.params["first_name"]&.strip
    pp_last_name = request.params["last_name"]&.strip
    if pp_first_name.nil? || pp_first_name.empty? || pp_last_name.nil? || pp_last_name.empty?
      flash :error, t(:'system/penpal/create/must_provide_name')
      return redirect request.path
    end

    @penpal = ReConnect::Models::Penpal.new(:user_id => nil)
    @penpal.save
    @penpal.encrypt(:first_name, pp_first_name)
    @penpal.encrypt(:last_name, pp_last_name)
    @penpal.save

    ReConnect::Models::PenpalFilter.create_filters_for(@penpal)

    flash :success, t(:'system/penpal/create/success')
    return redirect "/system/penpal/#{@penpal.id}"
  end
end
