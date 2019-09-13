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
      next halt 503, maintenance_render
    end

    # Set and check CSRF
    csrf_set!
    unless request.safe?
      next halt 403, "CSRF failed" unless csrf_ok?
    end

    if current_user_is_disabled?
      next halt haml(:'auth/user_disabled', :layout => :layout_minimal, :locals => {
        :title => t(:'auth/user_disabled/title'),
        :reason => current_user.decrypt(:disabled_reason),
      })
    end
  end

  not_found do
    haml :'errors/not_found', :layout => :layout_minimal, :locals => {
      :title => t(:'errors/not_found/title'),
      :no_flash => true,
    }
  end

  error 418 do
    haml :'errors/im_a_teapot', :layout => :layout_minimal, :locals => {
      :title => t(:'errors/im_a_teapot/title'),
      :no_flash => true,
    }
  end
end
