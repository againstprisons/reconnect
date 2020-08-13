require 'securerandom'

module ReConnect
  APP_CONFIG_ENTRIES = {
    "site-name" => {
      :type => :text,
      :default => "re:connect",
    },
    "org-name" => {
      :type => :text,
      :default => "Example Organisation",
    },
    "base-url" => {
      :type => :text,
      :default => "https://localhost",
    },
    "display-version" => {
      :type => :bool,
      :default => false,
    },
    "signups" => {
      :type => :bool,
      :default => false,
    },
    "signup-age-gate-enabled" => {
      :type => :bool,
      :default => false,
    },
    "signup-age-gate" => {
      :type => :text,
      :default => '18 years ago',
    },
    "signup-terms-agree-enabled" => {
      :type => :bool,
      :default => false,
    },
    "signup-terms-agree-text" => {
      :type => :text,
      :default => 'I confirm that I am over 18 years old',
    },
    "email-from" => {
      :type => :text,
      :default => 'reconnect@example.com',
    },
    "email-smtp-host" => {
      :type => :text,
      :default => 'logger',
    },
    "email-subject-prefix" => {
      :type => :text,
      :default => 'site-name-brackets',
    },
    "file-storage-dir" => {
      :type => :text,
      :default => '@SITEDIR@/files/',
    },
    "filter-enabled" => {
      :type => :bool,
      :default => true,
    },
    "filter-words" => {
      :type => :json,
      :default => '[]',
    },
    "penpal-statuses" => {
      :type => :json,
      :default => '["Application pending", "Active", "Unknown"]',
    },
    "penpal-status-default" => {
      :type => :text,
      :default => "Unknown",
    },
    "penpal-status-disable-sending" => {
      :type => :json,
      :default => "[]",
    },
    "penpal-status-transitions" => {
      :type => :json,
      :default => '[]',
    },
    "penpal-status-advocacy" => {
      :type => :text,
      :default => '',
    },
    "penpal-status-waiting-for-relationships" => {
      :type => :text,
      :default => "Application pending",
    },
    "penpal-allow-status-override" => {
      :type => :bool,
      :default => true,
    },
    "penpal-relationship-allow-archive" => {
      :type => :bool,
      :default => true,
    },
    "site-alert-emails" => {
      :type => :json,
      :default => '{"email": null, "alerts": ["*"]}',
    },
    "admin-profile-id" => {
      :type => :number,
      :default => 0,
    },
    "disable-email-to-prisons" => {
      :type => :bool,
      :default => false,
    },
    "disable-outside-correspondence-creation" => {
      :type => :bool,
      :default => false,
    },
    "disable-outside-file-upload" => {
      :type => :bool,
      :default => true,
    },
    "volunteer-group-ids" => {
      :type => :json,
      :default => '[]',
    },
  }

  APP_CONFIG_DEPRECATED_ENTRIES = {
    "allow-outside-file-upload" => {
      :in => "1.1.1",
      :reason => (
         "Moved to 'disable-outside-file-upload', keeping the name in line " \
         "with other 'disable-*' configuration entries."
      ),
    },
  }

  class Application
    configure do
      set :session_secret, ENV.fetch('SESSION_SECRET') {SecureRandom.hex(32)}
    end
  end
end
