class ReConnect::Controllers::SystemPenpalDeleteController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:delete")

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @penpal_name_a = @penpal.get_name
    @penpal_name = @penpal_name_a.map{|x| x == "" ? nil : x}.compact.join(" ")

    @user = nil
    @user = @penpal.user unless @penpal.user_id.nil?
    @user_name_a = @user_name = nil
    @user_name_a = @user.get_name if @user
    @user_name = @user_name_a.map{|x| x == "" ? nil : x}.compact.join(" ") if @user

    @title = t(:'system/penpal/delete/title', :name => @penpal_name, :id => @penpal.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/delete', :layout => false, :locals => {
          :title => @title,
          :penpal => @penpal,
          :name => @penpal_name,
          :name_a => @penpal_name_a,
          :user => @user,
          :user_name => @user_name,
          :user_name_a => @user_name_a,
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
