require File.expand_path(File.join("..", "setup.rb"), __FILE__)

require 'sinatra/base'
require 'yaml'
require 'sequel'
require 'mail'
require 'haml'
require 'addressable'

module ReConnect
  @@root = File.expand_path(File.join("..", ".."), __FILE__)

  def self.root
    @@root
  end

  require File.join(@@root, 'app', 'version')
  require File.join(@@root, 'app', 'utils')
  require File.join(@@root, 'app', 'server_utils')
  require File.join(@@root, 'app', 'workers')

  class << self
    attr_reader :app
    attr_accessor :database

    attr_accessor :site_dir, :theme_dir
    attr_accessor :app_config, :app_config_refresh_pending

    attr_accessor :default_language, :languages
  end

  def self.filter_strip_chars
    [
      " ",
      "\t",
      "\n",
      "(",
      ")",
      "[",
      "]",
      "{",
      "}",
      '"',
      "'",
      "#",
      /[\u0080-\u00ff]/, # all non-ASCII characters
    ]
  end

  def self.initialize(opts = {})
    # Set our environment if it's not already set
    ENV["APP_ENV"] = nil
    ENV["RACK_ENV"] ||= "production"

    # Encoding things
    Encoding.default_internal = Encoding::UTF_8
    Encoding.default_external = Encoding::UTF_8

    # Do an early environment check
    %w[SITE_DIR KEYDERIV_URL KEYDERIV_SECRET DATABASE_URL].each do |var|
      unless ENV.key?(var)
        raise "Required environment variable #{var} not present, dying."
      end
    end

    # Load crypto early for keyderiv check
    require File.join(ReConnect.root, 'app', 'crypto')

    # Check whether we can reach keyderiv before allowing the app to initialize
    unless opts[:no_check_keyderiv]
      begin
        ReConnect::Crypto.get_index_key "test", "test"
      rescue => e
        raise "Couldn't reach keyderiv, dying. (#{e.class.name}: #{e.message})"
      end
    end

    # load core modules
    require File.join(ReConnect.root, 'app', 'route')
    require File.join(ReConnect.root, 'app', 'controllers')
    require File.join(ReConnect.root, 'app', 'content_filter')
    require File.join(ReConnect.root, 'app', 'helpers')
    require File.join(ReConnect.root, 'app', 'models')

    # load the helpers
    ReConnect::Helpers.load_helpers

    # load the application
    require File.join(ReConnect.root, 'app', 'application')

    # and then load the controllers
    ReConnect::Controllers.load_controllers

    # language support
    @default_language = 'en'
    self.load_languages

    @database = Sequel.connect(ENV["DATABASE_URL"])
    @database.extension(:pagination)
    ReConnect::Models.load_models unless opts[:no_load_models]

    @app_config = {}
    @app_config_refresh_pending = []

    unless opts[:no_load_configs]
      # load config files (including site config)
      self.load_config

      # load config from database
      self.app_config_refresh(true) unless opts[:no_load_models]
    end

    @app = ReConnect::Application.new
  end

  def self.load_languages
    @languages = Dir.glob(File.join(ReConnect.root, 'config', 'translations', '*.yml')).map do |e|
      name = /(\w+)\.yml$/.match(e)[1]
      strings = YAML.load_file(e)

      [name, strings]
    end.to_h

    # In development mode, add a "language" that has no translated text, which
    # when t() is called, will display the translation key rather than any text
    if ENV['RACK_ENV'] == 'development'
      @languages["translationkeys"] = {
        :meta_description => "DEBUG: Translation keys"
      }
    end
  end

  def self.load_config
    require File.join(ReConnect.root, 'config', 'default_config.rb')
    require File.join(ReConnect.root, 'config', 'environments', "#{ENV["RACK_ENV"]}.rb")

    self.site_load_config
  end

  def self.app_config_refresh(force = false)
    return [] unless force || @app_config_refresh_pending.count.positive?
    keys = []

    ReConnect::APP_CONFIG_ENTRIES.each do |key, desc|
      next unless force || @app_config_refresh_pending.include?(key)
      keys << key

      cfg = ReConnect::Models::Config.find_or_create(:key => key) do |a|
        a.type = desc[:type].to_s

        a.value = desc[:default]
        if desc[:type] == :bool && !desc[:default].is_a?(String)
          a.value = (desc[:default] ? 'yes' : 'no')
        end
      end

      @app_config[key] = cfg.value.force_encoding(Encoding::UTF_8)
      @app_config[key].gsub!("@SITEDIR@", @site_dir) if @site_dir
      @app_config[key] = (cfg.value == 'yes') if desc[:type] == :bool

      self.app_config_refresh_file_storage_dir if key == 'file-storage-dir'
      self.app_config_refresh_mail if key == 'email-smtp-host'
      self.app_config_refresh_json(key) if key == 'filter-words'
      self.app_config_refresh_json(key) if key == 'penpal-statuses'
      self.app_config_refresh_nil_if_empty(key) if key == 'penpal-status-advocacy'
      self.app_config_refresh_json(key) if key == 'penpal-status-transitions'
      self.app_config_refresh_signup_age_gate if key == 'signup-age-gate'
      self.app_config_refresh_json(key) if key == 'site-alert-emails'
    end

    @app_config_refresh_pending.clear

    keys
  end

  def self.app_config_refresh_nil_if_empty(key)
    if @app_config[key].strip.empty?
      @app_config[key] = nil
    end
  end

  def self.app_config_refresh_json(key)
    begin
      loaded = JSON.parse(@app_config[key])
      @app_config[key] = loaded
    rescue => e
      puts "app_config_refresh_json(#{key}): Failed to parse JSON: #{e.class.name}: #{e}"
      puts e.traceback if e.respond_to?(:traceback)
      return
    end
  end

  def self.app_config_refresh_mail
    entry = @app_config["email-smtp-host"]&.strip
    return if entry.nil? || entry == ""

    if entry&.strip&.downcase == 'logger'
      return Mail.defaults do
        delivery_method :logger
      end
    end

    uri = nil
    begin
      uri = Addressable::URI.parse(entry)
    rescue => e
      puts "app_config_refresh_mail: Failed to parse email-smtp-host URI: #{e.class.name}: #{e}"
      puts e.traceback if e.respond_to?(:traceback)
      return
    end

    opts = {
      :address => uri.host,
      :port => uri.port,

      :enable_starttls_auto => uri.query_values ? uri.query_values["starttls"] == 'yes' : false,
      :enable_tls => uri.query_values ? uri.query_values["tls"] == 'yes' : false,
      :enable_ssl => uri.query_values ? uri.query_values["ssl"] == 'yes' : false,
      :openssl_verify_mode => uri.query_values ? uri.query_values["verify_mode"]&.strip&.upcase || 'PEER' : 'PEER',
      :ca_path => ENV["SSL_CERT_DIR"],
      :ca_file => ENV["SSL_CERT_FILE"],

      :authentication => uri.query_values ? uri.query_values["authentication"]&.strip&.downcase || 'plain' : 'plain',
      :user_name => Addressable::URI.unencode(uri.user || ''),
      :password => Addressable::URI.unencode(uri.password || ''),
    }

    @app_config["email-smtp-host"] = opts

    Mail.defaults do
      delivery_method :smtp, opts
    end
  end

  def self.app_config_refresh_file_storage_dir
    unless Dir.exist?(@app_config["file-storage-dir"])
      Dir.mkdir(@app_config["file-storage-dir"])
    end
  end

  def self.app_config_refresh_signup_age_gate
    loaded = Chronic.parse(@app_config['signup-age-gate'], :guess => true)
    return if !loaded.nil?

    puts "app_config_refresh_signup_age_gate: failed to parse date, setting default of 18 years"
    @app_config['signup-age-gate'] = '18 years ago'
  end

  def self.site_load_config
    site_dir = ENV["SITE_DIR"]
    return if site_dir.nil?
    return unless Dir.exist?(site_dir)

    @site_dir = site_dir

    if File.file?(File.join(@site_dir, "config.rb"))
      require File.join(@site_dir, "config.rb")
    end
  end

  def self.site_load_theme(theme_dir)
    return false unless Dir.exist?(theme_dir)
    @theme_dir = theme_dir
  end

  def self.new_content_filter
    f = ReConnect::ContentFilter.new
    f.enabled = @app_config["filter-enabled"]
    f.words = @app_config["filter-words"]

    f
  end
end
