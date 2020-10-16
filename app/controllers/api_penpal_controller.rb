class ReConnect::Controllers::ApiPenpalController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index

    @cid = request.params['cid'].to_i
    if @cid.positive?
      @penpal = ReConnect::Models::Penpal[@cid]

    # search by PRN
    else
      @prn = request.params['prn']&.strip&.downcase
      @prn = nil if @prn&.empty?
      if @prn
        ids = ReConnect::Models::PenpalFilter.perform_filter('prisoner_number', @prn).all.map(&:penpal_id).uniq

        if ids.count > 1
          return api_json({
            success: false,
            message: 'ambiguous PRN',
          })
        end

        @penpal = ReConnect::Models::Penpal[ids.first]
      end
    end

    unless @penpal
      return api_json({
        success: false,
        message: 'no penpal found',
      })
    end

    @relationships = ReConnect::Models::PenpalRelationship.find_for_single_penpal(@penpal)
    @relationships.map! do |x|
      other = x.penpal_one == @penpal.id ? x.penpal_two : x.penpal_one
      other = ReConnect::Models::Penpal[other]

      {
        id: x.id,
        other_party: {
          id: other.id,
          name: other.get_name,
          pseudonym: other.get_pseudonym,
          is_incarcerated: other.is_incarcerated,          
        },
      }
    end

    api_json({
      id: @penpal.id,
      prn: @penpal.decrypt(:prisoner_number),
      name: @penpal.get_name,
      pseudonym: @penpal.get_pseudonym,
      is_incarcerated: @penpal.is_incarcerated,
      prison: @penpal.decrypt(:prison_id).to_i,
      relationships: @relationships,
    })
  end
end
