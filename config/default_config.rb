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
      :type => :text,
      :default => '[]',
    },
    "penpal-statuses" => {
      :type => :text,
      :default => '["Application pending", "Active", "Unknown"]',
    },
    "penpal-status-default" => {
      :type => :text,
      :default => "Unknown",
    },
    "penpal-status-transitions" => {
      :type => :text,
      :default => '[]',
    },
    "penpal-status-advocacy" => {
      :type => :text,
      :default => '',
    },
    "site-alert-emails" => {
      :type => :text,
      :default => '{"email": null, "alerts": ["*"]}',
    },
    "allow-outside-file-upload" => {
      :type => :bool,
      :default => false,
    },
    "admin-profile-id" => {
      :type => :text,
      :default => "",
    }
  }

  class Application
    configure do
      set :session_secret, ENV.fetch('SESSION_SECRET') {SecureRandom.hex(32)}
    end
  end
end
