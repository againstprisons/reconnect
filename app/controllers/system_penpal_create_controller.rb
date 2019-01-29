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

    new_name = request.params["name"]&.strip
    if new_name.nil? || new_name == ""
      flash :error, t(:'system/penpal/create/must_provide_name')
      return redirect request.path
    end

    @penpal = ReConnect::Models::Penpal.new(:user_id => nil)
    @penpal.save
    @penpal.encrypt(:name, new_name)
    @penpal.save

    flash :success, t(:'system/penpal/create/success')
    return redirect "/system/penpal/#{@penpal.id}"
  end
end
