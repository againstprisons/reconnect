class ReConnect::Controllers::SystemPenpalRelationshipCorrespondenceCreateController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_one_name = "(unknown)" if @penpal_one_name.nil? || @penpal_one_name&.strip&.empty?
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    @penpal_two_name = "(unknown)" if @penpal_two_name.nil? || @penpal_two_name&.strip&.empty?

    @title = t(:'system/penpal/relationship/correspondence/create/title', :one_name => @penpal_one_name, :two_name => @penpal_two_name)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/relationship/correspondence/create', :layout => false, :locals => {
          :title => @title,
          :relationship => @relationship,
          :penpal_one => @penpal_one,
          :penpal_one_name => @penpal_one_name,
          :penpal_two => @penpal_two,
          :penpal_two_name => @penpal_two_name,
        })
      end
    end

    # get direction
    direction = request.params["direction"]&.strip&.downcase
    if direction.nil? || direction.empty?
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    unless params[:file]
      flash :error, t(:'system/penpal/relationship/correspondence/create/errors/no_file')
      return redirect request.path
    end

    # upload the file
    begin
      fn = params[:file][:filename]
      params[:file][:tempfile].rewind
      data = params[:file][:tempfile].read

      obj = ReConnect::Models::File.upload(data, :filename => fn)
      obj.save

    rescue => e
      flash :error, t(:'system/penpal/relationship/correspondence/create/errors/upload_failed')
      return redirect request.path
    end

    # create the correspondence
    c = ReConnect::Models::Correspondence.new
    c.creation = Time.now
    c.creating_user = current_user.id
    c.file_id = obj.file_id

    if direction == "1to2"
      c.sending_penpal = @penpal_one.id
      c.receiving_penpal = @penpal_two.id
    else
      c.sending_penpal = @penpal_two.id
      c.receiving_penpal = @penpal_one.id
    end

    c.save
    c.send!

    flash :success, t(:'system/penpal/relationship/correspondence/create/success', :id => c.id)
    return redirect to("/system/penpal/relationship/#{@relationship.id}/correspondence/#{c.id}")
  end
end
