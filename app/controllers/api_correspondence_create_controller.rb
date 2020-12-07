class ReConnect::Controllers::ApiCorrespondenceCreateController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @sending_penpal = ReConnect::Models::Penpal[request.params['sending'].to_i]
    @receiving_penpal = ReConnect::Models::Penpal[request.params['receiving'].to_i]
    @relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(@sending_penpal&.id, @receiving_penpal&.id)
    unless @relationship
      return api_json({
        success: false,
        message: 'no relationship with the penpals provided',
      })
    end

    unless params[:file]
      return api_json({
        success: false,
        message: 'no file provided',
      })
    end

    # upload the file
    begin
      fn = params[:file][:filename]
      params[:file][:tempfile].rewind
      data = params[:file][:tempfile].read

      opts = {filename: fn}
      mime_type = request.params['mime']&.strip&.downcase
      unless mime_type.nil? || mime_type&.empty?
        opts[:mime_type] = mime_type
      end

      obj = ReConnect::Models::File.upload(data, opts)
    rescue
      return api_json({
        success: false,
        message: 'failed to upload file',
      })
    end

    # explicit mime type setting

    # create the correspondence
    @correspondence = ReConnect::Models::Correspondence.new
    @correspondence.creation = Time.now
    @correspondence.file_id = obj.file_id
    @correspondence.sending_penpal = @sending_penpal.id
    @correspondence.receiving_penpal = @receiving_penpal.id
    @correspondence.save

    # send the correspondence
    @correspondence.send!

    # return the correspondence data
    @c_data = @correspondence.get_data()
    api_json({
      success: true,

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
