class ReConnect::Controllers::ApiPenpalController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @penpal = ReConnect::Models::Penpal[request.params['cid'].to_i]
    unless @penpal
      return api_json({
        success: false,
        message: 'no penpal with that ID',
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
      name: @penpal.get_name,
      pseudonym: @penpal.get_pseudonym,
      is_incarcerated: @penpal.is_incarcerated,
      relationships: @relationships,
    })
  end
end
