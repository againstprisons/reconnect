class ReConnect::Application < Sinatra::Base
  helpers ReConnect::Helpers::ApplicationHelpers

  set :environment, ENV["RACK_ENV"] ||= "production"
  set :default_encoding, "UTF-8"
  set :views, File.join('app', 'views')
  set :haml, :format => :html5, :default_encoding => "UTF-8"
  enable :sessions

  before do
    # Check if maintenance mode
    if is_maintenance? && !maintenance_path_allowed?
      next haml(:'maintenance/index', :layout => :layout_minimal, :locals => {
        :title => "Maintenance"
      })
    end

    # Set and check CSRF
    csrf_set!
    unless request.safe?
      next halt 403, "CSRF failed" unless csrf_ok?
    end
  end

  not_found do
    haml :'errors/not_found', :locals => {
      :title => t(:'errors/not_found/title'),
    }
  end
end
