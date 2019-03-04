class ReConnect::Controllers::SystemPenpalRelationshipCorrespondenceViewController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :get, "/mark", :method => :mark
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
    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two_name = @penpal_two.get_name

    @correspondence = ReConnect::Models::Correspondence[cid.to_i]
    return halt 404 unless @correspondence
    return halt 404 unless @correspondence.sending_penpal == @penpal_one.id || @correspondence.receiving_penpal == @penpal_one.id
    return halt 404 unless @correspondence.sending_penpal == @penpal_two.id || @correspondence.receiving_penpal == @penpal_two.id

    @correspondence_d = [@correspondence].map do |c|
      next if c.nil?

      sending = @penpal_one.id == c.sending_penpal ? @penpal_one : @penpal_two
      receiving = @penpal_one.id == c.receiving_penpal ? @penpal_one : @penpal_two

      actioned = !(c.actioning_user.nil?)
      actioning_user = ReConnect::Models::User[c.actioning_user]
      actioning_user_name = actioned ? actioning_user.decrypt(:name) : nil

      {
        :id => c.id,
        :creation => c.creation,

        :sending_penpal => sending,
        :sending_penpal_name => sending.get_name,
        :receiving_penpal => receiving,
        :receiving_penpal_name => receiving.get_name,
        :receiving_is_incarcerated => receiving.is_incarcerated,

        :actioned => actioned,
        :actioning_user => actioning_user,
        :actioning_user_name => actioning_user_name,
      }
    end.first

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
      })
    end
  end

  def mark(rid, cid)
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
      flash :error, t(:'system/penpal/relationship/correspondence/view/actions/mark/can_not_mark_outside')
      return redirect back
    end

    if @correspondence.actioning_user.nil?
      @correspondence.actioning_user = current_user.id
      flash :success, t(:'system/penpal/relationship/correspondence/view/actions/mark/marked')
    else
      @correspondence.actioning_user = nil
      flash :success, t(:'system/penpal/relationship/correspondence/view/actions/mark/unmarked')
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
