require File.expand_path("../config/reconnect.rb", __FILE__)
ReConnect.initialize :no_load_models => true, :no_load_configs => true, :no_check_keyderiv => true

def do_setup
  ReConnect::Models.load_models
  ReConnect.load_config
  ReConnect.app_config_refresh(:force => true)
end

namespace :db do
  desc "Run database migrations"
  task :migrate, [:version] do |t, args|
    Sequel.extension(:migration)

    migration_dir = File.expand_path("../migrations", __FILE__)
    version = nil
    version = args[:version].to_i if args[:version]

    Sequel::Migrator.run(ReConnect.database, migration_dir, :target => version)
  end
end

namespace :cfg do
  desc "Set default values for configuration keys that are not already set"
  task :defaults do |t|
    do_setup

    ReConnect::APP_CONFIG_ENTRIES.each do |key, desc|
      cfg = ReConnect::Models::Config.find_or_create(:key => key) do |a|
        a.type = desc[:type].to_s

        a.value = desc[:default].to_s
        if desc[:type] == :bool && !desc[:default].is_a?(String)
          a.value = (desc[:default] ? 'yes' : 'no')
        end
      end

      # correct configuration entry types
      if cfg.type != desc[:type].to_s
        cfg.type = desc[:type].to_s
        cfg.save
      end
    end
  end

  desc "Find configuration key duplicates"
  task :duplicates do |t|
    do_setup

    keys = {}
    ReConnect::Models::Config.all.each do |cfg|
      keys[cfg.key] ||= []
      keys[cfg.key] << [cfg.id, cfg.value]
    end

    keys.each do |key, values|
      if values.count > 1
        puts "Key #{key.inspect} has #{values.count} entries:"
        values.each do |v|
          puts "\tID #{v.first}: #{v.last.inspect}"
        end
      end
    end
  end
end

desc "Run an interactive console with the application loaded"
task :console do
  do_setup

  require 'pry'
  Pry.start
end
