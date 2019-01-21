require File.expand_path("../setup.rb", __FILE__)

require 'sinatra/base'
require 'yaml'
require 'sequel'
require 'mail'
require 'haml'

module ReConnect
  @@root = File.expand_path("../..", __FILE__)
  require File.join(@@root, 'app', 'version')
  require File.join(@@root, 'app', 'utils')

  class << self
    attr_reader :app
    attr_accessor :database

    attr_accessor :site_dir, :theme_dir
    attr_accessor :app_config, :app_config_refresh_pending

    attr_accessor :default_language, :languages
  end

  def self.root
    @@root
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
    ENV["RACK_ENV"] ||= "production"
    ENV["APP_ENV"] ||= ENV["RACK_ENV"]

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

    # load config files (including site config)
    self.load_config

    # load config from database
    @app_config = {}
    @app_config_refresh_pending = true
    self.app_config_refresh unless opts[:no_load_configs] || opts[:no_load_models]

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
    return unless force || @app_config_refresh_pending

    ReConnect::APP_CONFIG_ENTRIES.each do |key, desc|
      cfg = ReConnect::Models::Config.find_or_create(:key => key) do |a|
        a.type = desc[:type].to_s

        a.value = desc[:value]
        if desc[:type] == :bool && !desc[:value].is_a?(String)
          a.value = (desc[:value] ? 'yes' : 'no')
        end
      end

      value = cfg.value
      value = (cfg.value == 'yes') if desc[:type] == :bool

      @app_config[key] = value
    end

    @app_config_refresh_pending = false
  end

  def self.site_load_config
    site_dir = ENV["SITE_CONFIG_DIR"]
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
end
