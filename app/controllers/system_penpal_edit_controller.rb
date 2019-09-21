class ReConnect::Controllers::SystemPenpalEditController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @penpal_name_a = @penpal.get_name
    @penpal_name = @penpal_name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_pseudonym = @penpal.decrypt(:pseudonym)
    @penpal_pseudonym = nil if @penpal_pseudonym&.empty?
    @penpal_intro = @penpal.decrypt(:intro)
    @pp_data = penpal_view_data(@penpal)
    @prisons = ReConnect::Models::Prison.all.map do |p|
      {
        :id => p.id,
        :name => p.decrypt(:name),
      }
    end

    @user = nil
    @user = @penpal.user unless @penpal.user_id.nil?

    if @user
      flash :warning, t(:'system/penpal/edit/associated_user')
      return redirect back
    end

    @title = t(:'system/penpal/edit/title', :name => @penpal_name, :pseudonym => @penpal_pseudonym, :id => @penpal.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/edit', :layout => false, :locals => {
          :title => @title,
          :penpal => @penpal,
          :pp_data => @pp_data,
          :pseudonym => @penpal_pseudonym,
          :name => @penpal_name,
          :name_a => @penpal_name_a,
          :intro => @penpal_intro,
          :user => @user,
          :prisons => @prisons,
        })
      end
    end

    pp_first_name = request.params["first_name"]&.strip
    pp_last_name = request.params["last_name"]&.strip
    if pp_first_name.nil? || pp_first_name&.empty? || pp_last_name.nil? || pp_last_name&.empty?
      flash :error, t(:'system/penpal/edit/name_required')
      return redirect request.path
    end

    @penpal.encrypt(:first_name, pp_first_name)
    @penpal.encrypt(:last_name, pp_last_name)

    pp_pseudonym = request.params["pseudonym"]&.strip
    pp_pseudonym = nil if pp_pseudonym&.empty?
    @penpal.encrypt(:pseudonym, pp_pseudonym)

    pp_prisoner_number = request.params["prisoner_number"]&.strip
    pp_prisoner_number = nil if pp_prisoner_number&.empty?
    pp_prisoner_number = nil if pp_prisoner_number == '(unknown)' # XXX
    @penpal.encrypt(:prisoner_number, pp_prisoner_number)

    pp_intro = request.params["intro"]&.strip
    @penpal.encrypt(:intro, pp_intro)

    pp_birthday = request.params["birthday"]&.strip&.downcase
    pp_birthday = Chronic.parse(pp_birthday, :guess => true)
    @penpal.encrypt(:birthday, pp_birthday.strftime("%Y-%m-%d")) if pp_birthday

    pp_status = request.params["status"]&.strip
    if !(ReConnect.app_config['penpal-statuses'].include?(pp_status))
      pp_status = ReConnect.app_config['penpal-status-default']
    end
    @penpal.encrypt(:status, pp_status)

    @penpal.is_incarcerated = request.params["is_incarcerated"]&.strip&.downcase == "on"
    @penpal.is_advocacy = request.params["is_advocacy"]&.strip&.downcase == "on"
    @penpal.correspondence_guide_sent = request.params["correspondence_guide_sent"]&.strip&.downcase == "on"

    pp_release_date = request.params["release_date"]&.strip&.downcase
    pp_release_date = Chronic.parse(pp_release_date, :guess => true)
    @penpal.encrypt(:expected_release_date, pp_release_date.strftime("%Y-%m-%d")) if pp_release_date

    pp_creation = request.params["creation"]&.strip&.downcase
    pp_creation = Chronic.parse(pp_creation, :guess => true)
    @penpal.creation = pp_creation if pp_creation

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

    pp_prison = request.params["prison"]&.strip&.downcase.to_i
    if pp_prison.nil? || pp_prison.zero?
      pp_prison = nil
    else
      pp_prison = ReConnect::Models::Prison[pp_prison]&.id
    end
    @penpal.encrypt(:prison_id, pp_prison)

    @penpal.save

    ReConnect::Models::PenpalFilter.clear_filters_for(@penpal)
    ReConnect::Models::PenpalFilter.create_filters_for(@penpal)

    flash :success, t(:'system/penpal/edit/success')
    return redirect request.path
  end
end
