class ReConnect::Controllers::SystemPenpalViewController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/copy-link", :method => :copy_link

  def index(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[uid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name
    @user = @penpal.user

    @display_fields = [
      [t(:'penpal_id'), @penpal.id.inspect],
      [t(:'name'), @name],
      [t(:'system/penpal/view/relationship_count'), @penpal.relationship_count],
      [t(:'system/penpal/view/is_incarcerated'), @penpal.is_incarcerated ? 'yes' : 'no'],
    ]

    if @penpal.is_incarcerated
      prisoner_number = @penpal.decrypt(:prisoner_number)&.strip
      prisoner_number = "(unknown)" if prisoner_number.nil? || prisoner_number == ""
      @display_fields << [t(:'prisoner_number'), prisoner_number]

      address = @penpal.decrypt(:address)
        &.split("\n")
        &.map(&:strip)
        &.join(" / ")
      address = "(unknown)" if address.nil? || address == ""
      @display_fields << [t(:'address'), address]
    end

    @relationships = @penpal.relationships.map do |r|
      other_party = r.penpal_one
      other_party = r.penpal_two if other_party == @penpal.id
      other_party = ReConnect::Models::Penpal[other_party]
      next nil unless other_party

      {
        :id => r.id,
        :link => "/system/penpal/relationship/#{r.id}",
        :other_party => {
          :id => other_party.id,
          :name => other_party.get_name,
          :is_incarcerated => other_party.is_incarcerated,
        },
      }
    end.compact

    @copied_link = nil
    if session[:copied_penpal_id]
      copied = ReConnect::Models::Penpal[session[:copied_penpal_id]]
      if copied && copied.id != @penpal.id
        @copied_link = {
          :id => copied.id,
          :name => copied.get_name,
        }
      end
    end

    @title = t(:'system/penpal/view/title', :name => @name, :id => @penpal.id)
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/view', :layout => false, :locals => {
        :title => @title,
        :penpal => @penpal,
        :user => @user,
        :name => @name,
        :display_fields => @display_fields,
        :relationships => @relationships,
        :copied_link => @copied_link,
      })
    end
  end

  def copy_link(uid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @penpal = ReConnect::Models::Penpal[uid.to_i]
    return halt 404 unless @penpal
    @name = @penpal.get_name

    session[:copied_penpal_id] = @penpal.id
    flash :success, t(:'system/penpal/actions/copy_link/success', :name => @name, :id => @penpal.id)
    return redirect "/system/penpal/#{@penpal.id}"
  end
end
