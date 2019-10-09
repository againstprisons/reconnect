class ReConnect::Controllers::PenpalWaitingController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::PenpalWaitingHelpers

  add_route :get, "/"
  add_route :get, "/:ppid", :method => :compose
  add_route :post, "/:ppid", :method => :compose

  def index
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    # get the current user's penpal object, and then get the list of all
    # penpal IDs that the current user has a relationship with
    @our_penpal = current_user.penpal
    return halt 404 unless @our_penpal

    @our_relationships = []
    if @our_penpal
      @our_relationships = ReConnect::Models::PenpalRelationship.find_for_single_penpal(@our_penpal)
      @our_relationships = @our_relationships.map do |r|
        other_party = r.penpal_one
        other_party = r.penpal_two if other_party == @our_penpal.id

        other_party
      end
    end

    # get penpals waiting for relationships, excluding penpals that the
    # current user already has a relationship with
    @waiting_penpals = get_waiting_penpals
      .reject{|pp| @our_relationships.include? pp[:id]}

    @title = t(:'penpal/waiting/title')
    return haml(:'penpal/waiting/index', :locals => {
      :title => @title,
      :waiting_penpals => @waiting_penpals,
    })
  end

  def compose(ppid)
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    return halt 404 unless @penpal.is_incarcerated

    @penpal_name = @penpal.get_pseudonym
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?
    @title = t(:'penpal/waiting/compose/title', :name => @penpal_name)

    # get the current user's penpal object, and then get the list of all
    # penpal IDs that the current user has a relationship with
    @our_penpal = current_user.penpal
    return halt 404 unless @our_penpal

    @our_relationships = []
    if @our_penpal
      @our_relationships = ReConnect::Models::PenpalRelationship.find_for_single_penpal(@our_penpal)
      @our_relationships = @our_relationships.map do |r|
        other_party = r.penpal_one
        other_party = r.penpal_two if other_party == @our_penpal.id

        other_party
      end
    end

    # get penpals waiting for relationships, excluding penpals that the
    # current user already has a relationship with
    @waiting_penpals = get_waiting_penpals
      .reject{|pp| @our_relationships.include? pp[:id]}

    @waiting_penpal_ids = @waiting_penpals.map{|x| x[:id]}

    unless @waiting_penpal_ids.include?(@penpal.id)
      @title = t(:'penpal/waiting/satisfied/title')
      return haml(:'penpal/waiting/satisfied', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
      })
    end

    force_compose = request.params["compose"]&.strip&.downcase == "1"
    content = nil
    if request.post?
      content = request.params["content"]&.strip
      content = nil if content.nil? || content.empty?
    end

    if request.get? || force_compose
      return haml(:'penpal/waiting/compose', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :content => content,
      })
    end

    if content.nil? || content.empty?
      flash :error, t(:'penpal/waiting/compose/errors/no_text')
      return redirect to(request.path)
    end

    # Do a sanitize run
    content = Sanitize.fragment(content, Sanitize::Config::RELAXED)

    # Run content filter
    filter = ReConnect.new_content_filter
    matched = filter.do_filter(content)
    if matched.count.positive?
      flash :error, t(:'penpal/waiting/compose/errors/content_filter_matched', :matched => matched)
      return haml(:'penpal/waiting/compose', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :content => content,
      })
    end

    # Either show confirmation screen, or submit correspondence
    confirmed = request.params["confirm"]&.strip&.downcase == "1"
    unless confirmed
      return haml(:'penpal/waiting/compose_confirm', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :content => content,
      })
    end

    # Create relationship marked as unconfirmed
    @relationship = ReConnect::Models::PenpalRelationship.new({
      :penpal_one => @our_penpal.id,
      :penpal_two => @penpal.id,
      :confirmed => false,
    })
    @relationship.save

    # Save as file object
    obj = ReConnect::Models::File.upload(content, :filename => "#{DateTime.now.strftime("%Y-%m-%d_%H%M%S")}.html")
    obj.mime_type = "text/html"
    obj.save

    # create the correspondence
    c = ReConnect::Models::Correspondence.new
    c.creation = Time.now
    c.creating_user = current_user.id
    c.file_id = obj.file_id
    c.sending_penpal = @our_penpal.id
    c.receiving_penpal = @penpal.id
    c.save

    c.send!

    flash :success, t(:'penpal/waiting/compose/success', :penpal_name => @penpal_name)
    redirect to("/penpal/#{@penpal.id}")
  end
end
