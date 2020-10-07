class ReConnect::Controllers::ApiCorrespondenceGetController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @correspondence = ReConnect::Models::Correspondence[request.params['cid'].to_i]
    unless @correspondence
      return api_json({
        success: false,
        message: 'no correspondence with that ID',
      })
    end

    @c_data = @correspondence.get_data()
    api_json({
      id: @correspondence.id,
      creation: @correspondence.creation,
      file_id: @correspondence.file_id,
      sending_method: @c_data[:sending_method],
      
      relationship: {
        id: @c_data[:relationship].id,
        penpal_one: @c_data[:relationship].penpal_one,
        penpal_two: @c_data[:relationship].penpal_two,
      },

      sending_penpal: {
        id: @c_data[:sending_penpal].id,
        name: @c_data[:sending_penpal].get_name,
        pseudonym: @c_data[:sending_penpal].get_pseudonym,
        is_incarcerated: @c_data[:sending_is_incarcerated],
      },

      receiving_penpal: {
        id: @c_data[:receiving_penpal].id,
        name: @c_data[:receiving_penpal].get_name,
        pseudonym: @c_data[:receiving_penpal].get_pseudonym,
        is_incarcerated: @c_data[:receiving_is_incarcerated],
      },
    })
  end
end
