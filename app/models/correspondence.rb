require 'reverse_markdown'

class ReConnect::Models::Correspondence < Sequel::Model(:correspondence)
  include ReConnect::Helpers::EmailTemplateHelpers
  include ReConnect::Helpers::SiteAlertHelpers

  def self.find_for_relationship(relationship)
    [
      self.where(:sending_penpal => relationship.penpal_one, :receiving_penpal => relationship.penpal_two).all,
      self.where(:sending_penpal => relationship.penpal_two, :receiving_penpal => relationship.penpal_one).all,
    ].flatten.compact.sort{|a, b| b.creation <=> a.creation}
  end

  def get_data(current_penpal = nil)
    current_penpal = current_penpal.id if current_penpal.respond_to?(:id)

    penpal_sending = ReConnect::Models::Penpal[self.sending_penpal]
    penpal_sending_name = penpal_sending.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_sending_name = "(unknown)" if penpal_sending_name.nil? || penpal_sending_name&.strip&.empty?
    penpal_sending_pseudonym = penpal_sending.get_pseudonym
    penpal_sending_pseudonym = nil if penpal_sending_pseudonym&.empty?
    penpal_sending_name = "#{penpal_sending_name} (#{penpal_sending_pseudonym})" if penpal_sending_pseudonym
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]
    penpal_receiving_name = penpal_receiving.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_receiving_name = "(unknown)" if penpal_receiving_name.nil? || penpal_receiving_name&.strip&.empty?
    penpal_receiving_pseudonym = penpal_receiving.get_pseudonym
    penpal_receiving_pseudonym = nil if penpal_receiving_pseudonym&.empty?
    penpal_receiving_name = "#{penpal_receiving_name} (#{penpal_receiving_pseudonym})" if penpal_receiving_pseudonym

    relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(penpal_sending, penpal_receiving)

    actioned = !(self.actioning_user.nil?)
    actioning_user = ReConnect::Models::User[self.actioning_user]
    actioning_user_name = nil
    if actioning_user
      actioning_user_name = actioning_user.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
      actioning_user_name = "(unknown)" if actioning_user_name.nil? || actioning_user_name&.strip&.empty?
    end

    creating_user = ReConnect::Models::User[self.creating_user]
    creating_user_name = nil
    if creating_user
      creating_user_name = creating_user.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
      creating_user_name = "(unknown)" if creating_user_name.nil? || creating_user_name&.strip&.empty?
    end

    has_been_sent = self.sent.nil? || self.sent != "no"
    sending_method = has_been_sent ? self.sent.to_s : nil

    {
      :id => self.id,
      :creation => self.creation,

      :relationship => relationship,
      :sending_penpal => penpal_sending,
      :sending_penpal_name => penpal_sending_name,
      :sending_is_incarcerated => penpal_sending.is_incarcerated,
      :receiving_penpal => penpal_receiving,
      :receiving_penpal_name => penpal_receiving_name,
      :receiving_is_incarcerated => penpal_receiving.is_incarcerated,

      :this_user_sent => penpal_sending.id == current_penpal,
      :has_been_sent => has_been_sent,
      :sending_method => sending_method,

      :actioned => actioned || (sending_method == "email"),
      :actioning_user => actioning_user,
      :actioning_user_name => actioning_user_name,

      :creating_user => creating_user,
      :creating_user_name => creating_user_name,
    }
  end

  def send!
    return if self.sent == "archive"

    penpal_sending = ReConnect::Models::Penpal[self.sending_penpal]
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]
    relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(penpal_sending, penpal_receiving)
    return unless relationship

    if penpal_receiving.is_incarcerated
      if ReConnect.app_config['disable-email-to-prisons']
        return self.send_alert!
      end

      if relationship.email_approved
        out = self.send_email_to_prison!
        if out.is_a? ReConnect::Models::EmailQueue
          self.sent = "email"
          self.save

          return
        end
      end
    end

    self.send_alert!
  end

  def send_alert!
    return if self.sent == "archive"

    penpal_sending = ReConnect::Models::Penpal[self.sending_penpal]
    penpal_sending_name = penpal_sending.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_sending_name = "(unknown)" if penpal_sending_name.nil? || penpal_sending_name&.strip&.empty?
    penpal_sending_pseudonym = penpal_sending.get_pseudonym
    penpal_sending_pseudonym = nil if penpal_sending_pseudonym&.empty?
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]
    penpal_receiving_name = penpal_receiving.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_receiving_name = "(unknown)" if penpal_receiving_name.nil? || penpal_receiving_name&.strip&.empty?
    penpal_receiving_pseudonym = penpal_receiving.get_pseudonym
    penpal_receiving_pseudonym = nil if penpal_receiving_pseudonym&.empty?

    relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(penpal_sending, penpal_receiving)
    return unless relationship

    subject = "New correspondence" # TODO: translation

    if penpal_receiving.is_incarcerated
      template = "correspondence_to_incarcerated"

      url = Addressable::URI.parse(ReConnect.app_config["base-url"])
      url += "/system/penpal/relationship/#{relationship.id}/correspondence/#{self.id}"

      recipients = JSON.dump({
        "mode" => "roles",
        "roles" => [
          "site:penpal_alert_emails",
        ]
      })
    else
      if penpal_receiving.id == ReConnect.app_config['admin-profile-id'].to_i
        return unless should_send_alert_email('admin_correspondence')
        template = "correspondence_to_admin"
        subject = "New administrator correspondence"

        url = Addressable::URI.parse(ReConnect.app_config["base-url"])
        url += "/system/penpal/relationship/#{relationship.id}/correspondence/#{self.id}"

        recipients = JSON.dump({
          "mode" => "list",
          "list" => [
            ReConnect.app_config['site-alert-emails']['email'],
          ]
        })
      else
        user_receiving = ReConnect::Models::User[penpal_receiving.user_id]
        return unless user_receiving
        return if user_receiving.soft_deleted

        template = "correspondence_to_user"

        url = Addressable::URI.parse(ReConnect.app_config["base-url"])
        url += "/penpal/#{penpal_sending.id}/correspondence/#{self.id}"

        recipients = JSON.dump({
          "mode" => "list",
          "list" => [
            user_receiving.email,
          ]
        })
      end
    end

    data = {
      :link_to_correspondence => url.to_s,
      :relationship_confirmed => relationship.confirmed,
      :email_approved => relationship.email_approved,
      :email_to_prison_disabled => ReConnect.app_config['disable-email-to-prisons'],
      :penpal_sending => {
        :id => penpal_sending.id,
        :name => {
          :ary => penpal_sending.get_name,
          :first => penpal_sending.get_name&.first || '(unknown)',
          :joined => penpal_sending_name,
          :pseudonym => penpal_sending_pseudonym,
        },
      },
      :penpal_receiving => {
        :id => penpal_receiving.id,
        :name => {
          :ary => penpal_receiving.get_name,
          :first => penpal_receiving.get_name&.first || '(unknown)',
          :joined => penpal_receiving_name,
          :pseudonym => penpal_receiving_pseudonym,
        },
      },
    }

    email = ReConnect::Models::EmailQueue.new_from_template(template, data)
    email.queue_status = "queued"
    email.encrypt(:subject, subject)
    email.encrypt(:recipients, recipients)
    email.save
  end

  def send_email_to_prison!(force = false)
    return if self.sent == "archive"

    penpal_sending = ReConnect::Models::Penpal[self.sending_penpal]
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]
    relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(penpal_sending, penpal_receiving)
    return unless relationship
    return unless penpal_receiving.is_incarcerated

    # check that this relationship has email enabled, if it doesn't (and force
    # is not set) bail
    return unless force || relationship.email_approved

    # get prison info
    prison = ReConnect::Models::Prison[penpal_receiving.decrypt(:prison_id).to_i]
    return unless prison
    return if prison.email_address.nil?
    prison_email = prison.decrypt(:email_address)&.strip&.downcase
    return if prison_email.nil? || prison_email.empty?
    recipients = JSON.dump({
      "mode" => "list",
      "list" => [
        prison_email,
      ]
    })

    # get file info for this correspondence, bail if it's not text/html (which
    # it should be if it's been created by a normal user, since they only have
    # access to the html editor)
    file = ReConnect::Models::File.where(:file_id => self.file_id).first
    return unless file
    return unless file.mime_type == "text/html"

    # read in content
    html_part = file.decrypt_file

    # do a sanitize fragment run, just in case. sanitize runs are done on
    # creation for normal-user-created correspondence entries, but it may not
    # have been done if this was uploaded by an administrator. doesn't hurt to
    # do it again!
    html_part = Sanitize.fragment(html_part, Sanitize::Config::RELAXED)

    # construct plain-text version of the HTML contents using reverse-markdown
    text_part = ReverseMarkdown.convert(html_part, :unknown_tags => :bypass)

    penpal_receiving_name = penpal_receiving.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_receiving_name = "(unknown)" if penpal_receiving_name.nil? || penpal_receiving_name&.strip&.empty?

    # subject has to be "#{prisoner_name}, #{prisoner_number}"
    subject = [
      penpal_receiving_name,
      ", ",
      penpal_receiving.decrypt(:prisoner_number) || 'unknown prisoner number',
    ].join("")

    # wrap in layout_to_incarcerated
    template_data = OpenStruct.new({
      :site_name => ReConnect.app_config['site-name'],
      :org_name => ReConnect.app_config['org-name'],
    })

    html_template = new_tilt_template_from_fn("layout_to_incarcerated.html.erb")
    text_template = new_tilt_template_from_fn("layout_to_incarcerated.txt.erb")
    html_part = html_template.render(template_data) { html_part } if html_template
    text_part = text_template.render(template_data) { text_part } if text_template

    # create email queue entry
    email = ReConnect::Models::EmailQueue.new(:queue_status => "preparing")
    email.save
    email.queue_status = "queued"
    email.annotate_subject = false
    email.encrypt(:subject, subject)
    email.encrypt(:recipients, recipients)
    email.encrypt(:content_text, text_part)
    email.encrypt(:content_html, html_part)
    email.save

    email
  end

  def delete!
    ReConnect::Models::File.where(:file_id => self.file_id).first&.delete!
    self.delete
  end
end
