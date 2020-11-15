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

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]

    @since_ts = Time.at(request.params['since'].to_i)
    @correspondence = ReConnect::Models::Correspondence
      .find_for_relationship(@relationship)
      .reject { |x| x.creation < @since_ts }
      .sort { |a, b| a.creation <=> b.creation }

    @correspondence.map! do |x|
      has_been_sent = x.sent.nil? || x.sent != "no"
      sending_method = has_been_sent ? x.sent.to_s : nil

      {
        id: x.id,
        creation: x.creation,
        file_id: x.file_id,
        sending_method: sending_method,

        sending_penpal: x.sending_penpal,
        receiving_penpal: x.receiving_penpal,
      }
    end

    api_json({
      success: true,

      relationship: {
        id: @relationship.id,

        penpal_one: {
          id: @penpal_one.id,
          name: @penpal_one.get_name,
          pseudonym: @penpal_one.get_pseudonym,
          is_incarcerated: @penpal_one.is_incarcerated,
        },

        penpal_two: {
          id: @penpal_two.id,
          name: @penpal_two.get_name,
          pseudonym: @penpal_two.get_pseudonym,
          is_incarcerated: @penpal_two.is_incarcerated,
        },
      },

      since: @since_ts.to_i,
      correspondence: @correspondence,
    })
  end
end
