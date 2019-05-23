class ReConnect::Controllers::SystemPenpalViewController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/copy-link", :method => :copy_link

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[uid.to_i]
    return halt 404 unless @penpal
    @user = @penpal.user
    @penpal_name_a = @penpal.get_name
    @penpal_name = @penpal_name_a.map{|x| x == "" ? nil : x}.compact.join(" ")

    @pp_data = penpal_view_data(@penpal)

    @relationships = @penpal.relationships.map do |r|
      other_party = r.penpal_one
      other_party = r.penpal_two if other_party == @penpal.id
      other_party = ReConnect::Models::Penpal[other_party]
      next nil unless other_party

      {
        :id => r.id,
        :link => "/system/penpal/relationship/#{r.id}",
        :other_party => penpal_view_data(other_party),
      }
    end.compact

    @copied_link = nil
    if session[:copied_penpal_id]
      copied = ReConnect::Models::Penpal[session[:copied_penpal_id]]
      if copied && copied.id != @penpal.id
        @copied_link = {
          :id => copied.id,
          :name => copied.get_name,
        }
      end
    end

    @title = t(:'system/penpal/view/title', :name => @penpal_name, :id => @penpal.id)
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/view', :layout => false, :locals => {
        :title => @title,
        :penpal => @penpal,
        :user => @user,
        :name => @penpal_name,
        :name_a => @penpal_name_a,
        :display_fields => @pp_data[:display_fields],
        :relationships => @relationships,
        :copied_link => @copied_link,
      })
    end
  end

  def copy_link(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[uid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")

    session[:copied_penpal_id] = @penpal.id
    flash :success, t(:'system/penpal/actions/copy_link/success', :name => @name, :id => @penpal.id)
    return redirect "/system/penpal/#{@penpal.id}"
  end
end
