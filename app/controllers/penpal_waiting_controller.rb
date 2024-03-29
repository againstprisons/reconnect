class ReConnect::Controllers::PenpalWaitingController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::PenpalWaitingHelpers

  add_route :get, "/"
  add_route :get, "/:ppid", :method => :compose
  add_route :post, "/:ppid", :method => :compose

  def before
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end

    if ReConnect.app_config['disable-outside-correspondence-creation']
      return halt 404
    end

    @can_send_to_waiting = (current_user.disable_sending_to_waiting == false)
    unless @can_send_to_waiting
      return halt 404
    end

    # get the current user's penpal object, and then get the list of all
    # penpal IDs that the current user has a relationship with
    @current_user = current_user
    @current_penpal = ReConnect::Models::Penpal[@current_user.penpal_id]
    return halt 404 unless @current_penpal

    # get the current user's relationships
    @our_relationships = ReConnect::Models::PenpalRelationship.find_for_single_penpal(@current_penpal)
    @our_relationships = @our_relationships.map do |r|
      other_party = r.penpal_one
      other_party = r.penpal_two if other_party == @current_penpal.id

      other_party
    end

    # get penpals waiting for relationships, excluding penpals that the
    # current user already has a relationship with
    @waiting_penpals = get_waiting_penpals
      .reject{|pp| @our_relationships.include? pp[:id]}
    @waiting_penpal_ids = @waiting_penpals.map{|x| x[:id]}
  end

  def index
    @title = t(:'penpal/waiting/title')
    return haml(:'penpal/waiting/index', :locals => {
      :title => @title,
      :waiting_penpals => @waiting_penpals,
    })
  end

  def compose(ppid)
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    return halt 404 unless @penpal.is_incarcerated

    @penpal_prison = ReConnect::Models::Prison[@penpal.decrypt(:prison_id).to_i]
    return halt 404 unless @penpal_prison

    @penpal_name = @penpal.get_pseudonym
    @penpal_name = "(unknown)" if @penpal_name.nil? || @penpal_name.empty?
    @title = t(:'penpal/waiting/compose/title', :name => @penpal_name)

    unless @waiting_penpal_ids.include?(@penpal.id)
      @title = t(:'penpal/waiting/satisfied/title')
      return haml(:'penpal/waiting/satisfied', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
      })
    end

    # Check if prison requires a PRN, and if it does, check that this penpal has one set
    if @penpal_prison.require_prn
      prn = @penpal.decrypt(:prisoner_number)
      if prn.nil? || prn&.empty?
        flash :error, t(:'penpal/view/correspondence/create/errors/prison_requires_prn')
        return redirect back
      end
    end

    # Check that we don't have a temp block on sending to this prison
    if @penpal_prison.word_limit == -1
      flash :error, t(:'penpal/view/correspondence/create/errors/prison_temporary_block')
      return redirect back
    end

    force_compose = request.params["compose"]&.strip&.downcase == "1"
    content = nil
    pseudonym = @current_penpal.get_pseudonym
    if request.post?
      content = request.params["content"]&.strip
      content = nil if content&.empty?
      pseudonym = request.params["pseudonym"]&.strip

      if content.nil? || content&.empty?
        flash :error, t(:'penpal/waiting/compose/errors/no_text')
        force_compose = true
      end

      if pseudonym.nil? || pseudonym&.empty?
        flash :error, t(:'penpal/waiting/compose/errors/no_pseudonym')
        force_compose = true
      end
    end

    if request.get? || force_compose
      return haml(:'penpal/waiting/compose', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :content => content,
        :pseudonym => pseudonym,
        :intro => @penpal.decrypt(:intro)&.strip,
      })
    end

    # Remove invalid characters and do a sanitize run
    content.gsub!(/[^[:print:]]/, "\uFFFD")
    content = Sanitize.fragment(content, Sanitize::Config::BASIC)

    # Get word count
    wordcount = Sanitize.fragment(content).scan(/\w+/).count

    # If the prison being sent to has a word count limit, check the limit
    if @penpal_prison.word_limit&.positive?
      if wordcount > @penpal_prison.word_limit
        flash :error, t(:'penpal/waiting/compose/errors/over_prison_word_limit')
        return haml(:'penpal/waiting/compose', :locals => {
          :title => @title,
          :penpal => @penpal,
          :penpal_name => @penpal_name,
          :content => content,
          :pseudonym => pseudonym,
          :intro => @penpal.decrypt(:intro)&.strip,
        })
      end
    end

    # Run content filter
    filter = ReConnect.new_content_filter
    matched = filter.do_filter("#{content}\n<p>&mdash;<br>From: #{ERB::Util.html_escape(pseudonym)}</p>")
    if matched.count.positive?
      flash :error, t(:'penpal/waiting/compose/errors/content_filter_matched', :matched => matched)
      return haml(:'penpal/waiting/compose', :locals => {
        :title => @title,
        :penpal => @penpal,
        :penpal_name => @penpal_name,
        :content => content,
        :pseudonym => pseudonym,
        :intro => @penpal.decrypt(:intro)&.strip,
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
        :pseudonym => pseudonym,
        :intro => @penpal.decrypt(:intro)&.strip,
      })
    end

    # Append signature to content, now that we've confirmed the content
    content = "#{content}\n<p>&mdash;<br>From: #{ERB::Util.html_escape(pseudonym)}</p>"

=begin
    # If needed, save new pseudonym on current user & regenerate filters
    if pseudonym != @current_user.get_pseudonym
      @current_user.encrypt(:pseudonym, pseudonym)
      @current_user.save
      ReConnect::Models::PenpalFilter.clear_filters_for(@current_penpal)
      ReConnect::Models::PenpalFilter.create_filters_for(@current_penpal)
    end
=end

    # Create relationship marked as unconfirmed
    @relationship = ReConnect::Models::PenpalRelationship.new({
      :penpal_one => @current_penpal.id,
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
    c.sending_penpal = @current_penpal.id
    c.receiving_penpal = @penpal.id
    c.save

    c.send!

    flash :success, t(:'penpal/waiting/compose/success', :penpal_name => @penpal_name)
    redirect to("/penpal/#{@penpal.id}")
  end
end
