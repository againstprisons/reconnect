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
    attr_accessor :theme_dir

    attr_accessor :site_name, :org_name, :display_version

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

    self.load_configs unless opts[:no_load_configs]
    self.load_theme

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

  def self.load_configs
    require File.join(ReConnect.root, 'config', 'default_config.rb')
    require File.join(ReConnect.root, 'config', 'environments', "#{ENV["RACK_ENV"]}.rb")

    self.refresh_db_configs
  end

  def self.refresh_db_configs
    @site_name = "re:connect"
    ReConnect::Models::Config.where(key: 'site-name').each do |m|
      @site_name = m.value
    end

    @org_name = "Example Organisation"
    ReConnect::Models::Config.where(key: 'org-name').each do |m|
      @org_name = m.value
    end

    @display_version = false
    ReConnect::Models::Config.where(key: 'display-version').each do |m|
      @display_version = (m.value == 'yes')
    end
  end

  def self.load_theme
    @theme_dir = nil

    return unless ENV.key?("THEME_DIR")
    theme_dir = ENV["THEME_DIR"]
    return unless Dir.exist?(theme_dir)
    @theme_dir = theme_dir

    if File.file?(File.join(@theme_dir, "theme.rb"))
      require File.join(@theme_dir, "theme.rb")
    end
  end
end


