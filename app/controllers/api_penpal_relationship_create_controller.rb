class ReConnect::Controllers::ApiPenpalRelationshipCreateController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @penpal_one = ReConnect::Models::Penpal[request.params["penpal_one"]&.strip.to_i]
    @penpal_two = ReConnect::Models::Penpal[request.params["penpal_two"]&.strip.to_i]
    
    rl_confirmed = true
    if request.params.key?('confirmed')
      rl_confirmed = request.params['confirmed']&.strip.to_i.positive?
    end

    if @penpal_one.nil? || @penpal_two.nil?
      return api_json({
        success: false,
        message: 'one or more of the provided penpals does not exist',
      })
    end
    
    @relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(@penpal_one, @penpal_two)
    if @relationship
      return api_json({
        success: true,
        is_new: false,
        relationship: @relationship.id,
      })
    end
    
    @user_note = request.params['note']&.strip
    @user_note = nil if @user_note&.empty?
    @note = [
      "<p>This relationship was created by an API request at #{DateTime.now.to_s}</p>",
      @user_note,
    ].compact.join("\n")
    
    @relationship = ReConnect::Models::PenpalRelationship.new
    @relationship.penpal_one = @penpal_one.id
    @relationship.penpal_two = @penpal_two.id
    @relationship.confirmed = rl_confirmed
    @relationship.save # to get ID
    @relationship.encrypt(:notes, @note)
    @relationship.save
    
    return api_json({
      success: true,
      is_new: true,
      relationship: @relationship.id,
    })
  end
end
