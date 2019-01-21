class ReConnect::Controllers::StaticController < ReConnect::Controllers::ApplicationController
  VENDOR_WHITELIST = [
    "/purecss/build",
    "/font-awesome/css",
    "/font-awesome/fonts",
  ]

  add_route :get, "/styles.css", :method => 'styles_css'
  add_route :get, "/theme.css", :method => 'theme_css'
  add_route :get, "/vendor/*", :method => 'vendor'
  add_route :get, "/*"

  def before
    settings.views = {
      :scss => File.join("assets", "scss"),
      :default => File.join("app", "views"),
    }
  end

  def styles_css
    scss :styles, :style => :compressed, :layout => false
  end

  def theme_css
    return halt 404, "" unless ReConnect.theme_dir
    scss :theme, :style => :compressed, :layout => false
  end

  def vendor(splat)
    fn = File.expand_path(splat, "/")
    return halt 404, "" unless VENDOR_WHITELIST.map{|x| fn.start_with?(x)}.any?
    path = File.join(ReConnect.root, "node_modules", fn)
    return halt 404, "" unless File.file? path
    send_file path
  end

  def index(splat)
    fn = File.expand_path(splat, "/")
    path = File.join(ReConnect.root, "public", fn)
    if  ReConnect.theme_dir
      themepath = File.join(ReConnect.theme_dir, "public", fn)
      path = themepath if File.file? themepath
    end

    return halt 404, "" unless File.file? path
    send_file path
  end
end
