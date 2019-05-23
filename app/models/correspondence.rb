require 'reverse_markdown'

class ReConnect::Models::Correspondence < Sequel::Model(:correspondence)
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
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]
    penpal_receiving_name = penpal_receiving.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_receiving_name = "(unknown)" if penpal_receiving_name.nil? || penpal_receiving_name&.strip&.empty?

    actioned = !(self.actioning_user.nil?)
    actioning_user = ReConnect::Models::User[self.actioning_user]
    actioning_user_name = nil
    if actioning_user
      actioning_user_name = actioning_user.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
      actioning_user_name = "(unknown)" if actioning_user_name.nil? || actioning_user_name&.strip&.empty?
    end

    has_been_sent = self.sent.nil? || self.sent != "no"
    sending_method = has_been_sent ? self.sent.to_s : nil

    {
      :id => self.id,
      :creation => self.creation,

      :sending_penpal => penpal_sending,
      :sending_penpal_name => penpal_sending_name,
      :receiving_penpal => penpal_receiving,
      :receiving_penpal_name => penpal_receiving_name,
      :receiving_is_incarcerated => penpal_receiving.is_incarcerated,

      :this_user_sent => penpal_sending.id == current_penpal,
      :has_been_sent => has_been_sent,
      :sending_method => sending_method,

      :actioned => actioned || (sending_method == "email"),
      :actioning_user => actioning_user,
      :actioning_user_name => actioning_user_name,
    }
  end

  def send!
    penpal_sending = ReConnect::Models::Penpal[self.sending_penpal]
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]
    relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(penpal_sending, penpal_receiving)
    return unless relationship

    if penpal_receiving.is_incarcerated
      if relationship.email_approved
        self.send_email_to_prison!
        self.sent = "email"
        self.save
      else
        self.send_alert!
      end
    else
      self.send_alert!
    end
  end

  def send_alert!
    penpal_sending = ReConnect::Models::Penpal[self.sending_penpal]
    penpal_sending_name = penpal_sending.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_sending_name = "(unknown)" if penpal_sending_name.nil? || penpal_sending_name&.strip&.empty?
    penpal_receiving = ReConnect::Models::Penpal[self.receiving_penpal]
    penpal_receiving_name = penpal_receiving.get_name.map{|x| x == "" ? nil : x}.compact.join(" ")
    penpal_receiving_name = "(unknown)" if penpal_receiving_name.nil? || penpal_receiving_name&.strip&.empty?

    relationship = ReConnect::Models::PenpalRelationship.find_for_penpals(penpal_sending, penpal_receiving)
    return unless relationship

    if penpal_receiving.is_incarcerated
      # don't send an alert if automatic emails into prison have been approved
      # for this penpal relationship
      return if relationship.email_approved

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
      user_receiving = ReConnect::Models::User[penpal_receiving.user_id]
      return unless user_receiving

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

    data = {
      :link_to_correspondence => url.to_s,
      :penpal_sending => {
        :id => penpal_sending.id,
        :name => penpal_sending_name,
      },
      :penpal_receiving => {
        :id => penpal_receiving.id,
        :name => penpal_receiving_name,
      }
    }

    email = ReConnect::Models::EmailQueue.new_from_template(template, data)
    email.queue_status = "queued"
    email.encrypt(:subject, "New correspondence") # TODO: translation
    email.encrypt(:recipients, recipients)
    email.save
  end

  def send_email_to_prison!(force = false)
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

    # get file info for this correspondence, bail if it's not text/html (as it
    # should be), read in content
    file = ReConnect::Models::File.where(:file_id => self.file_id).first
    return unless file
    html_part = file.decrypt_file

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
