class ReConnect::Controllers::SystemPenpalDeleteController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:delete")

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name

    @user = nil
    @user = @penpal.user unless @penpal.user_id.nil?
    @user_name = nil
    @user_name = @user.decrypt(:name) if @user

    @title = t(:'system/penpal/delete/title', :name => @name, :id => @penpal.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/delete', :layout => false, :locals => {
          :title => @title,
          :penpal => @penpal,
          :name => @name,
          :user => @user,
          :user_name => @user_name,
        })
      end
    end

    unless request.params["confirm"]&.strip&.downcase == "on"
      flash :error, t(:'system/penpal/delete/confirm_not_checked')
      return redirect request.path
    end

    @penpal.delete!
    flash :success, t(:'system/penpal/delete/success')
    return redirect "/system/penpal"
  end
end
