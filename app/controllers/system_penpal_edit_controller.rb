class ReConnect::Controllers::SystemPenpalEditController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"
  add_route :get, "/rmincflag", :method => :rmincflag
  add_route :post, "/rmincflag", :method => :rmincflag

  def index(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:edit")

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

    @mail_optouts = ReConnect.app_config['mail-optout-categories'].map do |k, v|
      [
        k,
        {
          enabled: @penpal.mail_optout?(k),
          form_name: k.gsub(':', '__'),
          friendly: v,
        }
      ]
    end.to_h

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
          :mail_optouts => @mail_optouts,
        })
      end
    end

    pp_first_name = request.params["first_name"]&.strip
    pp_middle_name = request.params["middle_name"]&.strip
    pp_last_name = request.params["last_name"]&.strip
    if pp_first_name.nil? || pp_first_name&.empty? || pp_last_name.nil? || pp_last_name&.empty?
      flash :error, t(:'system/penpal/edit/name_required')
      return redirect request.path
    end

    @penpal.encrypt(:first_name, pp_first_name)
    @penpal.encrypt(:middle_name, pp_middle_name)
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

    if ReConnect.app_config["penpal-allow-status-override"]
      pp_status_override = request.params["status_override"]&.strip&.downcase == "on"
      @penpal.status_override = pp_status_override
    end
    
    do_remove_incarcerated = false
    is_incarcerated = request.params["is_incarcerated"]&.strip&.downcase == "on"
    if @penpal.is_incarcerated && !is_incarcerated
      do_remove_incarcerated = true
    else
      @penpal.is_incarcerated = is_incarcerated
    end

    @penpal.correspondence_guide_sent = request.params["correspondence_guide_sent"]&.strip&.downcase == "on"

    pp_release_date = request.params["release_date"]&.strip&.downcase
    pp_release_date = Chronic.parse(pp_release_date, :guess => true)
    @penpal.encrypt(:expected_release_date, pp_release_date.strftime("%Y-%m-%d")) if pp_release_date

    pp_creation = request.params["creation"]&.strip&.downcase
    pp_creation = Chronic.parse(pp_creation, :guess => true)
    @penpal.creation = pp_creation if pp_creation

    pp_optouts = @mail_optouts.map do |opt_k, opt_v|
      if request.params["mail_optout_#{opt_v[:form_name]}"]&.strip&.downcase == "on"
        opt_k
      else
        nil
      end
    end.compact
    @penpal.encrypt(:mail_optouts, pp_optouts.join(','))

    if ReConnect.app_config['penpal-status-advocacy']
      if pp_status == ReConnect.app_config['penpal-status-advocacy']
        unless @penpal.is_advocacy
          @is_advocacy = true
          flash :warning, t(:'system/penpal/edit/auto_set_advocacy_case', {
            :status => ReConnect.app_config['penpal-status-advocacy'],
          })
        end
      end
    end

    if @is_advocacy.nil?
      @is_advocacy = request.params["is_advocacy"]&.strip&.downcase == "on"
    end

    if @is_advocacy && !@penpal.is_advocacy
      # advocacy box just checked, so add a relationship with the advocacy
      # profile if one doesn't already exist

      advo_profile = ReConnect::Models::Penpal[ReConnect.app_config['advocacy-profile-id']]
      if advo_profile
        # check for relationship
        unless ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal, advo_profile)
          relationship = ReConnect::Models::PenpalRelationship.new
          relationship.penpal_one = advo_profile.id
          relationship.penpal_two = @penpal.id
          relationship.confirmed = true
          relationship.save
          relationship.encrypt(:notes, t(:'system/penpal/edit/auto_create_advocacy_relationship/relationship_note'))

          flash :warning, t(:'system/penpal/edit/auto_create_advocacy_relationship')
        end
      end
    end

    @penpal.is_advocacy = @is_advocacy

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

    if do_remove_incarcerated
      flash :warning, t(:'system/penpal/edit/success_remove_incarcerated')
      return redirect url("/system/penpal/#{@penpal.id}/edit/rmincflag")
    end

    flash :success, t(:'system/penpal/edit/success')
    return redirect request.path
  end

  def rmincflag(ppid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:edit")

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    return halt 418 unless @penpal.is_incarcerated

    @penpal_name_a = @penpal.get_name
    @penpal_name = @penpal_name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_pseudonym = @penpal.decrypt(:pseudonym)
    @penpal_pseudonym = nil if @penpal_pseudonym&.empty?
    @title = t(:'system/penpal/edit/rmincflag/title', :name => @penpal_name, :pseudonym => @penpal_pseudonym, :id => @penpal.id)

    # Generate a verification code and store it in the session if one
    # doesn't already exist there
    if session.key?(:rmincflag_apply_code)
      @verify_code = session[:rmincflag_apply_code]
    else
      @verify_code = Random.new.rand(100000000 .. 999999999).to_s
      session[:rmincflag_apply_code] = @verify_code
    end
    
    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/edit_rmincflag', :layout => false, :locals => {
          :title => @title,
          :penpal => @penpal,
          :pp_data => @pp_data,
          :pseudonym => @penpal_pseudonym,
          :name => @penpal_name,
          :name_a => @penpal_name_a,
          :verify_code => @verify_code,
        })
      end
    end

    # Check verification code
    form_verify = request.params['verify']&.strip
    if form_verify
      form_verify = form_verify.split(' ').map{|x| x.split('-')}.flatten.join('')
    end
    if form_verify != session[:rmincflag_apply_code]
      flash :error, t(:'system/penpal/edit/rmincflag/invalid_code')
      return redirect request.path
    end
    session.delete(:rmincflag_apply_code)

    # Remove incarcerated flag
    @penpal.is_incarcerated = false
    @penpal.save
    ReConnect::Models::PenpalFilter.clear_filters_for(@penpal)
    ReConnect::Models::PenpalFilter.create_filters_for(@penpal)

    flash :success, t(:'system/penpal/edit/rmincflag/success')
    redirect url("/system/penpal/#{@penpal.id}/edit")
  end
end
