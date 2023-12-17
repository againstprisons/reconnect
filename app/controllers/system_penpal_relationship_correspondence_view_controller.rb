class ReConnect::Controllers::SystemPenpalRelationshipCorrespondenceViewController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :post, "/mark", :method => :mark
  add_route :post, "/send", :method => :send_form
  add_route :get, "/delete", :method => :delete
  add_route :post, "/delete", :method => :delete

  def index(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:relationship:correspondence:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one_name = @penpal_one.get_name
    @penpal_one_pseudonym = @penpal_one.get_pseudonym
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name
    @penpal_two_pseudonym = @penpal_two.get_pseudonym
    @admin_profile = ReConnect::Models::Penpal[ReConnect.app_config['admin-profile-id']&.to_i]

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @penpal_one.id || @correspondence.receiving_penpal == @penpal_one.id
    return halt 404 unless @correspondence.sending_penpal == @penpal_two.id || @correspondence.receiving_penpal == @penpal_two.id

    @correspondence_d = [@correspondence].map{|x| x.get_data}.first

    @is_to_admin_profile = false
    if @admin_profile && @correspondence.receiving_penpal == @admin_profile.id
      @is_to_admin_profile = true
    end

    @file = ReConnect::Models::File.where(:file_id => @correspondence.file_id).first
    return halt 404 unless @file
    @file_token = @file.generate_download_token(current_user)
    @file_d = {
      :mime_type => @file.mime_type,
      :display_embed => @file.mime_type == 'application/pdf',
      :display_html => @file.mime_type == 'text/html',
      :html_content => @file.mime_type == 'text/html' ? @file.decrypt_file : nil,
      :download_token => @file_token,
      :download_url => url("/filedl/#{@file.file_id}/#{@file_token.token}?v=0"),
      :view_url => url("/filedl/#{@file.file_id}/#{@file_token.token}?v=1"),
    }

    @mark_form_url = request.path.to_s + "/mark"
    @send_form_url = request.path.to_s + "/send"
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
        :is_to_admin_profile => @is_to_admin_profile,
        :correspondence => @correspondence,
        :correspondence_d => @correspondence_d,
        :file => @file,
        :file_d => @file_d,
        :mark_form_url => @mark_form_url,
        :send_form_url => @send_form_url,
        :delete_form_url => @delete_form_url,
      })
    end
  end

  def mark(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:relationship:correspondence:mark")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @admin_profile = ReConnect::Models::Penpal[ReConnect.app_config['admin-profile-id']&.to_i]
    return halt 418 unless @admin_profile

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @penpal_one.id || @correspondence.receiving_penpal == @penpal_one.id
    return halt 404 unless @correspondence.sending_penpal == @penpal_two.id || @correspondence.receiving_penpal == @penpal_two.id

    @is_to_admin_profile = false
    if @admin_profile && @correspondence.receiving_penpal == @admin_profile.id
      @is_to_admin_profile = true
    end

    # only allow marking if this is directed to the admin profile
    return halt 418 unless @is_to_admin_profile

    # mark
    if @correspondence.actioning_user
      @correspondence.actioning_user = nil
      flash :success, t(:'system/penpal/relationship/correspondence/view/actions/mark/as_unread/success')
    else
      @correspondence.actioning_user = current_user.id
      flash :success, t(:'system/penpal/relationship/correspondence/view/actions/mark/as_read/success')
    end

    @correspondence.save

    return redirect url("/system/penpal/relationship/#{@relationship.id}/correspondence/#{@correspondence.id}")
  end


  def send_form(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:relationship:correspondence:send")

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

  def delete(rid, cid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:relationship:correspondence:delete")

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
