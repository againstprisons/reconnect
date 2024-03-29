class ReConnect::Controllers::SystemMassEmailController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::EmailTemplateHelpers
  include ReConnect::Helpers::MassEmailHelpers

  add_route :get, "/"
  add_route :post, "/"
  add_route :post, "/confirm", :method => :confirm
  add_route :post, "/send", :method => :send_email
  add_route :get, "/assoc/:type/:data", :method => :list_assoc
  add_route :get, "/view/:mid", :method => :view_email

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:mass_email")

    @title = t(:'system/mass_email/title')

    @subject = request["subject"]
    @subject = nil if @subject&.empty?
    @content = request["content"]
    @content = nil if @content&.empty?

    @to_groups = mass_email_groups(request["grp"])
    if !@to_groups && request["ppid"]&.strip.to_i.positive?
      pp = ReConnect::Models::Penpal[request.params["ppid"]&.strip.to_i]
      unless pp.nil? || !pp.is_incarcerated
        @penpal = {
          :id => pp.id,
          :name => pp.get_name&.compact&.join(' '),
          :pseudonym => pp.get_pseudonym,
        }
      end
    end

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/mass_email/index', :layout => false, :locals => {
        :title => @title,
        :to_groups => [@to_groups, mass_email_display_groups(@to_groups)],
        :penpal => @penpal,
        :subject => @subject,
        :content => @content,
      })
    end
  end

  def confirm
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:mass_email")

    @title = t(:'system/mass_email/title')

    @subject = request["subject"]
    @subject = nil if @subject&.empty?
    @content = request["content"]
    @content = nil if @content&.empty?

    @to_groups = mass_email_groups(request["grp"])
    if !@to_groups && request["ppid"]&.strip.to_i.positive?
      pp = ReConnect::Models::Penpal[request.params["ppid"]&.strip.to_i]
      unless pp.nil? || !pp.is_incarcerated
        @penpal = {
          :id => pp.id,
          :name => pp.get_name&.compact&.join(' '),
          :pseudonym => pp.get_pseudonym,
        }
      end
    end

    if @subject.nil? || @content.nil?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/mass_email/incomplete', :layout => false, :locals => {
          :title => @title,
          :to_groups => [@to_groups, mass_email_display_groups(@to_groups)],
          :penpal => @penpal,
          :subject => @subject,
          :content => @content,
        })
      end
    end

    # sanitize run
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)

    # render the content inside the template
    @rendered = @content
    template = new_tilt_template_from_fn("layout.html.erb")
    if template
      template_data = OpenStruct.new({
        :site_name => ReConnect.app_config["site-name"],
        :org_name => ReConnect.app_config["org-name"],
        :base_url => ReConnect.app_config["base-url"],
        :helpers => ReConnect::Helpers::InEmailHelpers.helper_methods,
      })

      @rendered = template.render(template_data) { @rendered }
    end

    # transform rendered into a data url for embedding in an iframe
    @rendered = "data:text/html;base64,#{Base64.strict_encode64(@rendered)}"

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/mass_email/confirm', :layout => false, :locals => {
        :title => @title,
        :to_groups => [@to_groups, mass_email_display_groups(@to_groups)],
        :penpal => @penpal,
        :subject => @subject,
        :content => @content,
        :rendered => @rendered,
      })
    end
  end

  def send_email
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:mass_email")

    @title = t(:'system/mass_email/title')

    @subject = request["subject"]
    @subject = nil if @subject&.empty?
    @content = request["content"]
    @content = nil if @content&.empty?

    @to_groups = mass_email_groups(request["grp"])
    if !@to_groups && request["ppid"]&.strip.to_i.positive?
      pp = ReConnect::Models::Penpal[request.params["ppid"]&.strip.to_i]
      unless pp.nil? || !pp.is_incarcerated
        @penpal = {
          :id => pp.id,
          :name => pp.get_name&.compact&.join(' '),
          :pseudonym => pp.get_pseudonym,
        }
      end
    end

    if @subject.nil? || @content.nil?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/mass_email/incomplete', :layout => false, :locals => {
          :title => @title,
          :to_groups => [@to_groups, mass_email_display_groups(@to_groups)],
          :penpal => @penpal,
          :subject => @subject,
          :content => @content,
        })
      end
    end

    # sanitize run
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)
    @content_text = ReverseMarkdown.convert(@content, :unknown_tags => :bypass)

    # if we're sending to volunteers, get the emails of all members of the
    # volunteer groups
    if @to_groups
      @grp_emails = @to_groups.map do |gid|
        ReConnect::Models::Group[gid.to_i]&.user_groups&.map(&:user)&.map(&:email)
      end.flatten.compact.uniq
    end

    # if we have a penpal, get the emails of their relationships
    if @penpal
      rs = ReConnect::Models::PenpalRelationship
        .find_for_single_penpal(@penpal[:id])

      emails = rs.map do |r|
        # don't include archived relationships in mass emails to penpals
        next nil if r.status_override

        if r.penpal_one == @penpal[:id]
          other = r.penpal_two
        else
          other = r.penpal_one
        end

        pp = ReConnect::Models::Penpal[other]
        next nil if pp.nil?
        next nil if pp.is_incarcerated

        u = ReConnect::Models::User[pp.user_id]
        next nil if u.nil?
        next nil if u.email.nil?
        next nil if u.email.empty?

        u.email
      end.compact.uniq

      @penpal[:r_emails] = emails
    end

    # construct recipients
    recipients = {"mode" => "all"}
    if @to_groups
      recipients = {
        "mode" => "list",
        "list" => @grp_emails,
      }
    elsif @penpal
      recipients = {
        "mode" => "list",
        "list" => @penpal[:r_emails],
      }
    end

    recipients = JSON.generate(recipients)

    # create emailqueue entry
    @queued = ReConnect::Models::EmailQueue.new_from_template(nil, {
      :content_html => @content,
      :content_text => @content_text,
    })

    if @to_groups
      @queued.recipient_assoc = "groups"
      @queued.recipient_assoc_data = @to_groups.map(&:to_s).join(',')
    elsif @penpal
      @queued.recipient_assoc = "penpal_rls"
      @queued.recipient_assoc_data = @penpal[:id].to_s
    else
      @queued.recipient_assoc = "all"
    end

    @queued.queue_status = "queued"
    @queued.encrypt(:subject, @subject)
    @queued.encrypt(:recipients, recipients)
    @queued.save

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/mass_email/sent', :layout => false, :locals => {
        :title => @title,
        :to_groups => [@to_groups, mass_email_display_groups(@to_groups)],
        :penpal => @penpal,
        :queue_id => @queued.id,
      })
    end
  end

  def list_assoc(type, data)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:mass_email:view")

    @title = t(:'system/mass_email/list_assoc/title')

    type = type&.downcase&.to_sym
    known = nil
    if type == :penpal_rls
      data = data.to_i.to_s
      return halt 404 if data.to_i.zero?
      known = ReConnect::Models::EmailQueue.where(recipient_assoc: type.to_s, recipient_assoc_data: data).all
    end

    return halt 404 if known.nil? || (known&.respond_to?(:empty?) && known&.empty?)

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/mass_email/list_assoc', :layout => false, :locals => {
        :title => @title,
        :assoc => [type, data],
        :known => known,
      })
    end
  end

  def view_email(mid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:mass_email:view")

    @email = ReConnect::Models::EmailQueue[mid]
    return halt 404 unless @email
    @title = t(:'system/mass_email/view_email/title', meid: mid)

    @rendered = @email.decrypt(:content_html)
    @rendered = "data:text/html;base64,#{Base64.strict_encode64(@rendered)}"

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/mass_email/view_email', :layout => false, :locals => {
        :title => @title,
        :email => @email,
        :rendered => @rendered,
      })
    end
  end
end
