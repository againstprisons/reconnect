require 'tilt/erb'
require 'ostruct'

class ReConnect::Models::EmailQueue < Sequel::Model(:email_queue)
  def self.new_from_template(template, data = {})
    # TODO: allow setting language, check if template exists for given language
    # and default to ReConnect.default_language should the template not exist
    lang = "en"

    # add generic data
    data[:site_name] = ReConnect.app_config["site-name"]
    data[:org_name] = ReConnect.app_config["org-name"]

    # convert to ostruct
    data = OpenStruct.new(data)

    # get text version template
    text_filename = File.join(lang, "#{template}.txt.erb")
    text_theme_path = File.join(ReConnect.theme_dir, "views", "email_templates", text_filename) unless ReConnect.theme_dir.nil? || ReConnect.theme_dir.empty? 
    text_path = File.join(ReConnect.root, "app", "views", "email_templates", text_filename)
    text_path = text_theme_path if File.exist?(text_theme_path) unless ReConnect.theme_dir.nil? || ReConnect.theme_dir.empty? 
    text_template = nil
    text_template = Tilt::ERBTemplate.new(text_path) if File.exist?(text_path)

    # get html version template
    html_filename = File.join(lang, "#{template}.html.erb")
    html_theme_path = File.join(ReConnect.theme_dir, "views", "email_templates", html_filename) unless ReConnect.theme_dir.nil? || ReConnect.theme_dir.empty? 
    html_path = File.join(ReConnect.root, "app", "views", "email_templates", html_filename)
    html_path = text_theme_path if File.exist?(html_theme_path) unless ReConnect.theme_dir.nil? || ReConnect.theme_dir.empty? 
    html_template = nil
    html_template = Tilt::ERBTemplate.new(html_path) if File.exist?(html_path)

    # render templates
    text_output = nil
    text_output = text_template.render(data) if text_template
    html_output = nil
    html_output = html_template.render(data) if html_template

    # create new EmailQueue instance
    entry = self.new(:queue_status => "preparing")
    entry.save # save to get an ID
    entry.encrypt(:content_text, text_output) if text_output
    entry.encrypt(:content_html, html_output) if html_output

    entry
  end

  def self.annotate_subject(text)
    out = ""
    case ReConnect.app_config["email-subject-prefix"]
    when "none"
      return text
    when "org-name"
      return "#{ReConnect.app_config["org-name"]}: #{text}"
    when "org-name-brackets"
      return "[#{ReConnect.app_config["org-name"]}] #{text}"
    when "site-name"
      return "#{ReConnect.app_config["site-name"]}: #{text}"
    else # site-name-brackets
      return "[#{ReConnect.app_config["site-name"]}] #{text}"
    end
  end

  def self.recipients_list(data)
    mode = data["mode"]&.strip&.downcase
    if mode == "list"
      return data["list"]
    elsif mode == "roles"
      roles = data["roles"].map(&:strip).map(&:downcase)
      uids = []

      roles.each do |role|
        ReConnect::Models::UserRole.where(:role => role).all.each do |ur|
          uids << ur.user_id
        end
      end

      return uids.uniq.map do |uid|
        ReConnect::Models::User[uid]&.email
      end.compact
    end

    []
  end

  def generate_recipients_list
    return [] if self.recipients.nil?

    data = JSON.parse(self.decrypt(:recipients))
    self.class.recipients_list(data)
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

      if this.annotate_subject
        subject this.class.annotate_subject(this.decrypt(:subject))
      else
        subject this.decrypt(:subject)
      end

      unless this.content_text.nil?
        text_part do
          content_type 'text/plain; charset=UTF-8'
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
