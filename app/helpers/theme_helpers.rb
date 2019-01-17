module ReConnect::Helpers::ThemeHelpers 
  def find_template(views, name, engine, &block)
    if views.instance_of? Hash
      _, folder = views.detect do |k, v|
        engine == Tilt[k]
      end

      folder ||= views[:default]
    else
      folder = views
    end

    app_folder = File.join(ReConnect.root, folder)

    begin
      raise "no theme dir" unless ReConnect.theme_dir
      theme_folder = File.join(ReConnect.theme_dir, folder)

      found = false
      Tilt.default_mapping.extensions_for(engine).each do |extension|
        fn = "#{name}.#{extension}"
        if File.file?(File.join(theme_folder, fn))
          found = fn
        end
      end

      raise "template not in theme dir" unless found
      super(theme_folder, name, engine, &block)

    rescue => e
      super(app_folder, name, engine, &block)
    end
  end
end
