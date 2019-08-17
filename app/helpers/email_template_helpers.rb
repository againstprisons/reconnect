module ReConnect::Helpers::EmailTemplateHelpers
  def new_tilt_template_from_fn(filename)
    path = File.join(ReConnect.root, "app", "views", "email_templates", filename)

    if ReConnect.theme_dir
      theme_path = File.join(ReConnect.theme_dir, "views", "email_templates", filename)
      if File.file?(theme_path)
        path = theme_path
      end
    end

    return nil unless File.file?(path)
    Tilt::ERBTemplate.new(path)
  end
end
