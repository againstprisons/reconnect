class ReConnect::Controllers::ApiPenpalCreateController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @name_first = request.params['name_first']&.strip
    @name_first = nil if @name_first&.empty?
    @name_middle = request.params['name_middle']&.strip
    @name_middle = nil if @name_middle&.empty?
    @name_last = request.params['name_last']&.strip
    @name_last = nil if @name_last&.empty?
    @pseudonym = request.params['pseudonym']&.strip
    @pseudonym = nil if @pseudonym&.empty?
    @prn = request.params['prn']&.strip
    @prn = nil if @prn&.empty?    
    @status = request.params['status']&.strip
    @status = 'Active' if @status.nil? || @status&.empty?
    @prison = ReConnect::Models::Prison[request.params['prison']&.strip.to_i]

    errs = [
      @name_first.nil?,
      @name_last.nil?,
      @prn.nil?,
      !(ReConnect.app_config['penpal-statuses'].include?(@status)),
    ]
    
    if errs.any?
      return api_json({
        success: false,
        message: 'one or more required fields were not provided',
      })
    end

    # Check for existing penpal with this PRN
    prn = @prn.strip.downcase
    ReConnect::Models::PenpalFilter.perform_filter('prisoner_number', prn).each do |pf|
      pp = ReConnect::Models::Penpal[pf.penpal_id]
      if pp.decrypt(:prisoner_number)&.strip&.downcase == prn 
        return api_json({
          success: true,
          is_new: false,
          penpal: pp.id,
        })
      end
    end

    # Set up a note saying this penpal was created by an API request
    @user_note = request.params['note']&.strip
    @user_note = nil if @user_note&.empty?
    @note = [
      "<p>This penpal was created by an API request at #{DateTime.now.to_s}</p>",
      @user_note,
    ].compact.join('\n')

    # Create the penpal
    @penpal = ReConnect::Models::Penpal.new(:user_id => nil, :is_incarcerated => true, :creation => Time.now)
    @penpal.save
    @penpal.encrypt(:first_name, @name_first)
    @penpal.encrypt(:middle_name, @name_middle) if @name_middle
    @penpal.encrypt(:last_name, @name_last)
    @penpal.encrypt(:pseudonym, @pseudonym) if @pseudonym
    @penpal.encrypt(:prisoner_number, @prn)
    @penpal.encrypt(:status, @status)
    @penpal.encrypt(:prison_id, @prison&.id)
    @penpal.encrypt(:notes, @note)
    @penpal.save
    
    # Create the penpal filters
    ReConnect::Models::PenpalFilter.create_filters_for(@penpal)
    
    # Create the relationship with the administration profile
    admin_pid = ReConnect.app_config['admin-profile-id'].to_i
    unless admin_pid.zero?
      admin_profile = ReConnect::Models::Penpal[admin_pid]
      if admin_profile
        relationship_message = (
          "This relationship was created automatically on creation of this " +
          "incarcerated penpal, at #{DateTime.now.to_s}."
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
    
    return api_json({
      success: true,
      is_new: true,
      penpal: @penpal.id,
    })
  end
end