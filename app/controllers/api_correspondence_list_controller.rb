class ReConnect::Controllers::ApiCorrespondenceListController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @relationship = ReConnect::Models::PenpalRelationship[request.params['cid'].to_i]
    unless @relationship
      return api_json({
        success: false,
        message: 'no relationship with that ID',
      })
    end

    @since_ts = Time.at(request.params['since'].to_i)
    @correspondence = ReConnect::Models::Correspondence
      .find_for_relationship(@relationship)
      .reject { |x| x.creation < @since_ts }
      .sort { |a, b| a.creation <=> b.creation }

    @correspondence.map! do |x|
      has_been_sent = x.sent.nil? || x.sent != "no"
      sending_method = has_been_sent ? x.sent.to_s : nil
      sending_penpal = ReConnect::Models::Penpal[x.sending_penpal]
      receiving_penpal = ReConnect::Models::Penpal[x.receiving_penpal]

      {
        id: x.id,
        creation: x.creation,
        file_id: x.file_id,
        sending_method: sending_method,

        sending_penpal: {
          id: sending_penpal.id,
          name: sending_penpal.get_name,
          pseudonym: sending_penpal.get_pseudonym,
          is_incarcerated: sending_penpal.is_incarcerated,
        },

        receiving_penpal: {
          id: receiving_penpal.id,
          name: receiving_penpal.get_name,
          pseudonym: receiving_penpal.get_pseudonym,
          is_incarcerated: receiving_penpal.is_incarcerated,
        },
      }
    end




    api_json({
      relationship: {
        id: @relationship.id,
        penpal_one: @relationship.penpal_one,
        penpal_two: @relationship.penpal_two,
      },

      since: @since_ts.to_i,
      correspondence: @correspondence,
    })
  end
end
