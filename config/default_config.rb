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
    "filter-words" => {
      :type => :text,
      :default => '[]',
    }
  }

  class Application
    configure do
      set :session_secret, ENV.fetch('SESSION_SECRET') {SecureRandom.hex(32)}
    end
  end
end
