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

    @penpal_status = @penpal.decrypt(:status)&.strip
    @sending_enabled = !(ReConnect.app_config['penpal-status-disable-sending'].include?(@penpal_status))
    @sending_enabled = false if @penpal_status.nil? || @penpal_status.empty?
    @sending_enabled = false unless @relationship.confirmed
    @sending_enabled = false if ReConnect.app_config['disable-outside-correspondence-creation']

    @penpal_name = @penpal.get_pseudonym
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?

    @title = t(:'penpal/view/title', :name => @penpal_name)

    @correspondence = [
      ReConnect::Models::Correspondence.where(:receiving_penpal => @current_penpal.id, :sending_penpal => @penpal.id).all,
      ReConnect::Models::Correspondence.where(:sending_penpal => @current_penpal.id, :receiving_penpal => @penpal.id).all,
    ].flatten.compact.map{|x| x.get_data(@current_penpal)}.compact.sort{|a, b| b[:creation] <=> a[:creation]}

    haml :'penpal/view', :locals => {
      :title => @title,
      :penpal => @penpal,
      :penpal_name => @penpal_name,
      :relationship => @relationship,
      :correspondence => @correspondence,
      :sending_enabled => @sending_enabled,
    }
  end
end
