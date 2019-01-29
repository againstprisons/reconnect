class ReConnect::Models::EmailQueue < Sequel::Model(:email_queue)
  def self.annotate_subject(text)
    out = ""
    case ReConnect.app_config["email-subject-prefix"]
    when "none"
      out = text
    when "org-name"
      out = "#{ReConnect.app_config["org-name"]}: #{text}"
    when "org-name-brackets"
      out = "[#{ReConnect.app_config["org-name"]}] #{text}"
    when "site-name"
      out = "#{ReConnect.app_config["site-name"]}: #{text}"
    else # site-name-brackets
      out = "[#{ReConnect.app_config["site-name"]}] #{text}"
    end

    return out.force_encoding("UTF-8")
  end

  def generate_recipients_list
    return [] if self.recipients.nil?

    recipients = JSON.parse(self.decrypt(:recipients))
    if recipients["mode"]&.strip&.downcase == "list"
      return recipients["list"]
    else
      return []
    end
  end

  def generate_messages_chunked
    out = []

    chunks = self.generate_recipients_list.each_slice(25).to_a
    chunks.each do |chunk|
      m = self.generate_message_no_recipients
      m.bcc = chunk

      out << m
    end

    out
  end

  def generate_message_no_recipients
    this = self

    m = Mail.new do
      from ReConnect.app_config["email-from"]
      subject this.class.annotate_subject(this.decrypt(:subject))

      unless this.content_text.nil?
        text_part do
          body this.decrypt(:content_text) 
        end
      end

      unless this.content_html.nil?
        html_part do
          content_type 'text/html; charset=UTF-8'
          body this.decrypt(:content_html)
        end
      end

      unless this.attachments.nil?
        attachments = JSON.parse(this.decrypt(:attachments))
        attachments.each do |at|
          add_file :filename => at["filename"], :content => at["content"]
        end
      end
    end

    m.header["Return-Path"] = "<>"
    m.header["Auto-Submitted"] = "auto-generated"

    m
  end
end
