class ReConnect::Controllers::SystemPenpalRelationshipController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemPenpalHelpers

  add_route :get, "/"
  add_route :get, "/email-approve", :method => :email_approve
  add_route :post, "/notes", :method => :notes

  def index(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one = penpal_view_data(@penpal_one) if @penpal_one
    @penpal_one_name = @penpal_one&.key?(:name) ? @penpal_one[:name] : "(unknown)"
    @penpal_one_pseudonym = @penpal_one&.key?(:pseudonym) ? @penpal_one[:pseudonym] : "(unknown)"

    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two = penpal_view_data(@penpal_two) if @penpal_two
    @penpal_two_name = @penpal_two&.key?(:name) ? @penpal_two[:name] : "(unknown)"
    @penpal_two_pseudonym = @penpal_two&.key?(:pseudonym) ? @penpal_two[:pseudonym] : "(unknown)"

    @email_approved = {
      :approved => @relationship.email_approved == true,
      :by => nil,
    }

    if @relationship.email_approved_by_id
      user = ReConnect::Models::User[@relationship.email_approved_by_id]
      if user
        @email_approved[:by] = {
          :id => user.id,
          :name => user.get_name.map{|x| x == "" ? nil : x}.compact.join(" ") || "(unknown)",
        }
      end
    end

    @correspondence = ReConnect::Models::Correspondence.find_for_relationship(@relationship)
    @notes = @relationship.decrypt(:notes)

    @title = t(:'system/penpal/relationships/title', {
      :one_name => @penpal_one_name,
      :one_pseudonym => @penpal_one_pseudonym,
      :two_name => @penpal_two_name,
      :two_pseudonym => @penpal_two_pseudonym,
    })

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/relationship/index', :layout => false, :locals => {
        :title => @title,
        :relationship => @relationship,
        :penpal_one => @penpal_one,
        :penpal_two => @penpal_two,
        :email_approved => @email_approved,
        :notes => @notes,
        :correspondence => {
          :count => @correspondence.count,
          :last => @correspondence.first&.creation,
        },
      })
    end
  end

  def email_approve(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    @penpal_one = ReConnect::Models::Penpal[@relationship.penpal_one]
    @penpal_one = penpal_view_data(@penpal_one) if @penpal_one
    @penpal_one_name = @penpal_one&.key?(:name) ? @penpal_one[:name] : "(unknown)"
    @penpal_one_pseudonym = @penpal_one&.key?(:pseudonym) ? @penpal_one[:pseudonym] : "(unknown)"

    @penpal_two = ReConnect::Models::Penpal[@relationship.penpal_two]
    @penpal_two = penpal_view_data(@penpal_two) if @penpal_two
    @penpal_two_name = @penpal_two&.key?(:name) ? @penpal_two[:name] : "(unknown)"
    @penpal_two_pseudonym = @penpal_two&.key?(:pseudonym) ? @penpal_two[:pseudonym] : "(unknown)"

    approved = @relationship.email_approved == true
    if approved
      @relationship.email_approved = false
      @relationship.email_approved_by_id = nil

      flash :success, t(:'system/penpal/relationships/email_approve/revoke/success')
    else
      @relationship.email_approved = true
      @relationship.email_approved_by_id = current_user.id

      flash :success, t(:'system/penpal/relationships/email_approve/approve/success')
    end

    @relationship.save
    return redirect back
  end

  def notes(rid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @relationship = ReConnect::Models::PenpalRelationship[rid.to_i]
    return halt 404 unless @relationship

    notes = request.params["notes"]&.strip
    if notes.nil? || notes.empty?
      @relationship.notes = nil
    else
      @relationship.encrypt(:notes, notes)
    end

    @relationship.save

    flash :success, t(:'system/penpal/relationships/notes/success')
    return redirect back
  end
end
