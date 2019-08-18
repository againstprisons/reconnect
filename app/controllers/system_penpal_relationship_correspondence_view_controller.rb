class ReConnect::Controllers::SystemPenpalRelationshipCorrespondenceViewController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/send", :method => :send_form
  add_route :get, "/download", :method => :download
  add_route :get, "/delete", :method => :delete
  add_route :post, "/delete", :method => :delete

  def index(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name
    @penpal_one_pseudonym = @penpal_one.get_pseudonym
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name
    @penpal_two_pseudonym = @penpal_two.get_pseudonym

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @penpal_one.id || @correspondence.receiving_penpal == @penpal_one.id
    return halt 404 unless @correspondence.sending_penpal == @penpal_two.id || @correspondence.receiving_penpal == @penpal_two.id

    @correspondence_d = [@correspondence].map{|x| x.get_data}.first

    @file = ReConnect::Models::File.where(:file_id => @correspondence.file_id).first
    return halt 404 unless @file
    @file_d = {
      :mime_type => @file.mime_type,
      :display_html => @file.mime_type == 'text/html',
      :html_content => @file.mime_type == 'text/html' ? @file.decrypt_file : nil,
    }

    @send_form_url = request.path.to_s + "/send"
    @download_form_url = request.path.to_s + "/download"
    @delete_form_url = request.path.to_s + "/delete"

    @title = t(:'system/penpal/relationship/correspondence/view/title', :id => @correspondence.id)

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/relationship/correspondence/view', :layout => false, :locals => {
        :title => @title,
        :relationship => @relationship,
        :penpal_one => @penpal_one,
        :penpal_one_d => penpal_view_data(@penpal_one),
        :penpal_two => @penpal_two,
        :penpal_two_d => penpal_view_data(@penpal_two),
        :correspondence => @correspondence,
        :correspondence_d => @correspondence_d,
        :file => @file,
        :file_d => @file_d,
        :send_form_url => @send_form_url,
        :download_form_url => @download_form_url,
        :delete_form_url => @delete_form_url,
      })
    end
  end

  def send_form(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @penpal_one.id || @correspondence.receiving_penpal == @penpal_one.id
    return halt 404 unless @correspondence.sending_penpal == @penpal_two.id || @correspondence.receiving_penpal == @penpal_two.id

    receiving = @penpal_one.id == @correspondence.receiving_penpal ? @penpal_one : @penpal_two
    unless receiving.is_incarcerated
      flash :error, t(:'system/penpal/relationship/correspondence/view/actions/send/can_not_mark_outside')
      return redirect back
    end

    if @correspondence.sent != "no"
      flash :error, t(:'system/penpal/relationship/correspondence/view/actions/send/already_sent')
      return redirect back
    end

    method = request.params["send_method"]&.strip&.downcase
    case method
    when "post"
      @correspondence.actioning_user = current_user.id
      @correspondence.sent = "post"
      @correspondence.save

      flash :success, t(:'system/penpal/relationship/correspondence/view/actions/send/via_post/success')

    when "email"
      # check the receiving penpal is incarcerated and that their prison has an email address`
      prison = ReConnect::Models::Prison[receiving.decrypt(:prison_id).to_i]
      if prison.nil? || prison.email_address.nil?
        flash :error, t(:'system/penpal/relationship/correspondence/view/actions/send/via_email/invalid_prison')
        return redirect back
      end

      @correspondence.send_email_to_prison!(true)
      @correspondence.actioning_user = current_user.id
      @correspondence.sent = "email"
      @correspondence.save

      flash :success, t(:'system/penpal/relationship/correspondence/view/actions/send/via_email/success')

    else
      flash :error, t(:'system/penpal/relationship/correspondence/view/actions/send/invalid_method')
      return redirect back
    end

    @correspondence.save
    return redirect back
  end

  def download(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @penpal_one.id || @correspondence.receiving_penpal == @penpal_one.id
    return halt 404 unless @correspondence.sending_penpal == @penpal_two.id || @correspondence.receiving_penpal == @penpal_two.id

    @file = ReConnect::Models::File.where(:file_id => @correspondence.file_id).first
    return halt 404 unless @file

    @token = @file.generate_download_token(current_user)

    return redirect to("/filedl/#{@file.file_id}/#{@token.token}")
  end

  def delete(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @penpal_one.id || @correspondence.receiving_penpal == @penpal_one.id
    return halt 404 unless @correspondence.sending_penpal == @penpal_two.id || @correspondence.receiving_penpal == @penpal_two.id

    @title = t(:'system/penpal/relationship/correspondence/delete/title', :id => @correspondence.id)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/penpal/relationship/correspondence/delete', :layout => false, :locals => {
          :title => @title,
          :relationship => @relationship,
          :penpal_one => @penpal_one,
          :penpal_one_name => @penpal_one_name,
          :penpal_two => @penpal_two,
          :penpal_two_name => @penpal_two_name,
          :correspondence => @correspondence,
        })
      end
    end

    if request.params["confirm"]&.strip&.downcase == "on"
      @correspondence.delete!
      flash :success, t(:'system/penpal/relationship/correspondence/delete/success', :id => cid)
      return redirect to("/system/penpal/relationship/#{@relationship.id}/correspondence")
    end

    flash :success, t(:'system/penpal/relationship/correspondence/delete/confirm_not_checked')
    return redirect request.path
  end
end
