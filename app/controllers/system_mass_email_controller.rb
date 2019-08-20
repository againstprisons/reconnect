class ReConnect::Controllers::SystemMassEmailController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::EmailTemplateHelpers

  add_route :get, "/"
  add_route :post, "/"
  add_route :post, "/confirm", :method => :confirm
  add_route :post, "/send", :method => :send_email

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:mass_email")

    @title = t(:'system/mass_email/title')

    @subject = request["subject"]
    @subject = nil if @subject&.empty?
    @content = request["content"]
    @content = nil if @content&.empty?

    @penpal = nil
    if request["ppid"]&.strip.to_i.positive?
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

    @penpal = nil
    if request["ppid"]&.strip.to_i.positive?
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

    @penpal = nil
    if request["ppid"]&.strip.to_i.positive?
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
          :penpal => @penpal,
          :subject => @subject,
          :content => @content,
        })
      end
    end

    # sanitize run
    @content = Sanitize.fragment(@content, Sanitize::Config::RELAXED)
    @content_text = ReverseMarkdown.convert(@content, :unknown_tags => :bypass)

    # if we have a penpal, get the emails of their relationships
    if @penpal
      rs = ReConnect::Models::PenpalRelationship
        .find_for_single_penpal(@penpal[:id])

      emails = rs.map do |r|
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
    if @penpal
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
    @queued.queue_status = "queued"
    @queued.encrypt(:subject, @subject)
    @queued.encrypt(:recipients, recipients)
    @queued.save

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/mass_email/sent', :layout => false, :locals => {
        :title => @title,
        :penpal => @penpal,
        :queue_id => @queued.id,
      })
    end
  end
end
