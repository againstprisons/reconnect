class ReConnect::Controllers::SystemPenpalCreateController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:create")

    @title = t(:'system/penpal/create/title')
    @prisons = ReConnect::Models::Prison.all.map do |p|
      {
        :id => p.id,
        :name => p.decrypt(:name),
      }
    end

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/create', :layout => false, :locals => {
          :title => @title,
          :prisons => @prisons,
        })
      end
    end

    pp_first_name = request.params["first_name"]&.strip
    pp_middle_name = request.params["middle_name"]&.strip
    pp_last_name = request.params["last_name"]&.strip
    if pp_first_name.nil? || pp_first_name.empty? || pp_last_name.nil? || pp_last_name.empty?
      flash :error, t(:'system/penpal/create/must_provide_name')
      return redirect request.path
    end

    pp_pseudonym = request.params["pseudonym"]&.strip
    pp_pseudonym = nil if pp_pseudonym&.empty?
    pp_prisoner_number = request.params["prisoner_number"]&.strip

    pp_status = request.params["status"]&.strip
    if !(ReConnect.app_config['penpal-statuses'].include?(pp_status))
      pp_status = ReConnect.app_config['penpal-status-default']
    end
    set_advo = pp_status == ReConnect.app_config['penpal-status-advocacy']

    pp_prison = request.params["prison"]&.strip&.downcase.to_i
    if pp_prison.nil? || pp_prison.zero?
      pp_prison = nil
    else
      pp_prison = ReConnect::Models::Prison[pp_prison]&.id
    end

    @penpal = ReConnect::Models::Penpal.new(:user_id => nil, :is_incarcerated => true, :creation => Time.now)
    @penpal.save
    @penpal.encrypt(:first_name, pp_first_name)
    @penpal.encrypt(:middle_name, pp_middle_name)
    @penpal.encrypt(:last_name, pp_last_name)
    @penpal.encrypt(:pseudonym, pp_pseudonym) if pp_pseudonym
    @penpal.encrypt(:prisoner_number, pp_prisoner_number)
    @penpal.encrypt(:status, pp_status)
    @penpal.encrypt(:prison_id, pp_prison)

    if ReConnect.app_config['penpal-status-advocacy']
      if pp_status == ReConnect.app_config['penpal-status-advocacy']
        unless @penpal.is_advocacy
          @penpal.is_advocacy = true
          flash :warning, t(:'system/penpal/edit/auto_set_advocacy_case', {
            :status => ReConnect.app_config['penpal-status-advocacy'],
          })
        end
      end
    end

    admin_pid = ReConnect.app_config['admin-profile-id']&.to_i
    if !admin_pid.nil? && !admin_pid.zero?
      admin_profile = ReConnect::Models::Penpal[admin_pid]
      if admin_profile
        relationship_message = (
          "This relationship was created automatically on creation of this " +
          "incarcerated penpal, at #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}."
        )

        r = ReConnect::Models::PenpalRelationship.new({
          :penpal_one => admin_pid,
          :penpal_two => @penpal.id,
          :email_approved => true,
          :email_approved_by_id => nil,
          :confirmed => true,
        })

        r.save # to get ID
        r.encrypt(:notes, relationship_message)
        r.save
      end
    end

    @penpal.save

    ReConnect::Models::PenpalFilter.create_filters_for(@penpal)

    flash :success, t(:'system/penpal/create/success')
    return redirect "/system/penpal/#{@penpal.id}"
  end
end
