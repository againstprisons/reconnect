class ReConnect::Controllers::SystemConfigurationMailController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemConfigurationHelpers

  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:access") || has_role?("system:configuration:edit")

    @title = t(:'system/configuration/mail/title')
    @entries = config_mail_entries

    uri = Addressable::URI.parse(@entries["email-smtp-host"][:value])
    @smtp_uri = {
      :uri => uri,

      :address => uri.host,
      :port => uri.port,

      :enable_starttls_auto => uri.query_values ? uri.query_values["starttls"] == 'yes' : false,
      :enable_tls => uri.query_values ? uri.query_values["tls"] == 'yes' : false,
      :openssl_verify_mode => uri.query_values ? uri.query_values["verify_mode"]&.strip&.upcase || 'PEER' : 'PEER',

      :authentication => uri.query_values ? uri.query_values["authentication"]&.strip&.downcase || 'plain' : 'plain',
      :user_name => Addressable::URI.unencode(uri.user || ''),
      :password => Addressable::URI.unencode(uri.password || ''),
    }

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/configuration/mail', :layout => false, :locals => {
          :title => @title,
          :entries => @entries,
          :smtp_uri => @smtp_uri,
        })
      end
    end

    @from_email = request.params["from_email"]&.strip&.downcase
    if @from_email.nil? || @from_email == ""
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    @subject_prefix = request.params["subject_prefix"]&.strip&.downcase
    unless %w[none org-name org-name-brackets site-name site-name-brackets].include?(@subject_prefix)
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    begin
      smtp_uri = Addressable::URI.new
      smtp_uri.host = request.params["smtp_address"]&.strip&.downcase || 'localhost'
      smtp_uri.port = (request.params["smtp_port"]&.strip || '587').to_i

      user = Addressable::URI.encode(request.params["smtp_username"]&.strip&.downcase)
      smtp_uri.user = user unless user.nil? || user == ""
      password = Addressable::URI.encode(request.params["smtp_password"]&.strip&.downcase)
      smtp_uri.password = password unless password.nil? || password == ""

      smtp_uri.query_values = {
        "starttls" => request.params["smtp_starttls"]&.strip&.downcase == "on" ? 'yes' : 'no',
        "tls" => request.params["smtp_tls"]&.strip&.downcase == "on" ? 'yes' : 'no',
        "authentication" => request.params["smtp_authentication"]&.strip&.downcase || 'plain',
        "verify_mode" => request.params["smtp_verify_mode"]&.strip&.upcase || 'PEER',
      }

      @smtp_uri_s = smtp_uri.to_s
    rescue
      flash :error, t(:'required_field_missing') + " (uri)"
      return redirect request.path
    end

    if @entries["email-from"][:value] != @from_email
      email_from_cfg = ReConnect::Models::Config.where(:key => 'email-from').first
      email_from_cfg.value = @from_email
      email_from_cfg.save

      unless ReConnect.app_config_refresh_pending.include?("email-from")
        ReConnect.app_config_refresh_pending << "email-from"
      end
    end

    if @entries["email-subject-prefix"][:value] != @subject_prefix
      subject_prefix_cfg = ReConnect::Models::Config.where(:key => 'email-subject-prefix').first
      subject_prefix_cfg.value = @subject_prefix
      subject_prefix_cfg.save

      unless ReConnect.app_config_refresh_pending.include?("email-subject-prefix")
        ReConnect.app_config_refresh_pending << "email-subject-prefix"
      end
    end

    if @entries["email-smtp-host"][:value] != @smtp_uri_s
      smtp_cfg = ReConnect::Models::Config.where(:key => 'email-smtp-host').first
      smtp_cfg.value = @smtp_uri_s
      smtp_cfg.save

      unless ReConnect.app_config_refresh_pending.include?("email-smtp-host")
        ReConnect.app_config_refresh_pending << "email-smtp-host"
      end
    end

    flash :success, t(:'system/configuration/mail/success')
    return redirect request.path
  end
end
