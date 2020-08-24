class ReConnect::Controllers::SystemVolunteerRosterController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemVolunteerRosterHelpers

  add_route :get, "/"
  add_route :post, "/"
  add_route :get, "/override/:date", :method => :override
  add_route :post, "/override/:date", :method => :override

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:roster:access")

    @user = current_user
    @can_assign = has_role?('system:roster:self_assign')
    @can_override = has_role?('system:roster:admin')

    @roster_start = Chronic.parse(request.params['start']&.strip) if request.params['start']
    @roster_start ||= DateTime.now
    @roster = roster_month(@roster_start)

    @title = t(:'system/roster/title')

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/roster/index', :layout => false, :locals => {
          :title => @title,
          :roster => @roster,
          :can_assign => @can_assign,
          :can_override => @can_override,
        })
      end
    end

    # POST actions follow

    return halt 403 unless @can_assign

    date = Chronic.parse(request.params['date']&.strip&.downcase)&.to_date
    unless date
      flash :error, t(:'system/roster/assign/errors/invalid_date')
      return redirect request.path
    end

    unless (@roster[:ts_start] .. @roster[:ts_end]).to_a.include?(date)
      flash :error, t(:'system/roster/assign/errors/invalid_date')
      return redirect request.path
    end

    # Check for existing VRE
    vre = ReConnect::Models::VolunteerRosterEntry.where(roster_day: date).first
    if vre 
      unless @can_override
        # Only allow admins to change an existing VRE
        flash :error, t(:'system/roster/assign/errors/already_assigned')
        return redirect request.path
      end

      # If we're here, this is an override. Redirect to the override route
      return redirect "/system/roster/override/#{date.strftime('%Y-%m-%d')}"
    end

    vre = ReConnect::Models::VolunteerRosterEntry.new(user_id: @user.id, roster_day: date)
    vre.save

    flash :success, t(:'system/roster/assign/success', :date => date)
    redirect request.path
  end

  def override(date)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:roster:admin")

    @user = current_user
    @date = Chronic.parse(date.strip)&.to_date

    return halt 404 unless @date
    if @date < DateTime.now.to_date
      flash :error, t(:'system/roster/override/errors/in_past')
      return redirect '/system/roster'
    end

    @back = "/system/roster?start=#{@date.strftime('%Y-%m-01')}"
    @vre = ReConnect::Models::VolunteerRosterEntry.where(roster_day: @date).first
    @title = t(:'system/roster/override/title', :date => @date)
    @users = roster_available_volunteers()

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/roster/override', :layout => false, :locals => {
          :r_back => @back,
          :title => @title,
          :date => @date,
          :vre => @vre,
          :users => @users,
        })
      end
    end

    # POST actions follow

    if request.params['delete']&.strip.to_i.positive?
      @vre&.delete

      flash :success, t(:'system/roster/override/delete/success', :date => @date)
      return redirect @back
    end

    override_user = ReConnect::Models::User[request.params['user']&.strip.to_i]
    unless override_user
      flash :error, t(:'system/roster/override/choose/errors/invalid_user')
      return redirect request.path
    end

    @vre&.delete
    @nvre = ReConnect::Models::VolunteerRosterEntry.new(user_id: override_user.id, roster_day: @date)
    @nvre.is_admin_override = true
    @nvre.save

    flash :success, t(:'system/roster/override/choose/success', :date => @date, :user => @nvre.get_user_name)
    redirect @back
  end
end
