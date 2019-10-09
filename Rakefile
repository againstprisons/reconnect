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

namespace :release do
  desc "Change version to given version"
  task :change_version, [:version] do |t, args|
    abort "version not provided" unless args[:version]
    puts "Updating version to #{args[:version]}"

    # Change app/version.rb
    version_rb_path = File.expand_path("../app/version.rb", __FILE__)
    version_rb = File.read(version_rb_path)
    old_version_rb = /VERSION = "(.*)"/.match(version_rb)[1]
    puts "version.rb was at #{old_version_rb}"
    version_rb.gsub!("VERSION = \"#{old_version_rb}\"", "VERSION = \"#{args[:version]}\"")
    File.open(version_rb_path, 'w') do |f|
      f.write(version_rb)
    end

    # Change package.json
    package_json_path = File.expand_path("../package.json", __FILE__)
    package_json = JSON.parse(File.read(package_json_path))
    puts "package.json was at #{package_json["version"]}"
    package_json["version"] = args[:version]
    File.open(package_json_path, 'w') do |f|
      f.write(JSON.pretty_generate(package_json) + "\n")
    end

    puts "You should now run 'npm install' to update lockfiles, and then tag the release as \"v#{args[:version]}\" and 'git push --tags'."
  end
end

desc "Run an interactive console with the application loaded"
task :console do
  do_setup

  require 'pry'
  Pry.start
end
