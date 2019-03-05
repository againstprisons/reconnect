class ReConnect::Controllers::PenpalController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index(ppid)
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @current_penpal = ReConnect::Models::Penpal[current_user.penpal_id]
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal

    @relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal, @current_penpal)
    return halt 404 unless @relationship

    @title = t(:'penpal/view/title', :name => @penpal.get_name)

    @correspondence = [
      ReConnect::Models::Correspondence.where(:receiving_penpal => @current_penpal.id, :sending_penpal => @penpal.id).all,
      ReConnect::Models::Correspondence.where(:sending_penpal => @current_penpal.id, :receiving_penpal => @penpal.id).all,
    ].flatten.compact.map{|x| x.get_data(@current_penpal)}.compact.sort{|a, b| b[:creation] <=> a[:creation]}

    haml :'penpal/view', :locals => {
      :title => @title,
      :penpal => @penpal,
      :penpal_name => @penpal.get_name,
      :relationship => @relationship,
      :correspondence => @correspondence,
    }
  end
end
