require 'tilt/erb'
require 'ostruct'

class ReConnect::Controllers::SystemDebuggingEmailTemplatePreviewController < ReConnect::Controllers::ApplicationController
  add_route :get, "/:lang/:template.:type"

  def index(lang, template, type)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:debugging")

    data = {}
    unless request.params["data"].nil?
      begin
        data = JSON.parse(request.params["data"]).to_a.map{|x| [x.first.to_sym, x.last]}.to_h
      rescue => e
        flash :error, t(:'system/debugging/emailpreview/invalid_data', :message => e.inspect)
      end
    end

    # add generic data
    data[:site_name] = site_name
    data[:org_name] = org_name

    # convert to ostruct
    data = OpenStruct.new(data)

    # get template filename and path
    filename = File.join(lang, "#{template}.#{type}.erb")
    theme_path = File.join(ReConnect.theme_dir, "views", "email_templates", filename)
    path = File.join(ReConnect.root, "app", "views", "email_templates", filename)
    path = theme_path if File.exist?(theme_path) # if template in theme exists, use that

    # abort if template does not exist
    unless File.exist?(path)
      flash :error, t(:'system/debugging/emailpreview/template_does_not_exist', :filename => filename)
      return haml(:'system/layout', :locals => {:title => nil}) {""}
    end

    # render template
    template = Tilt::ERBTemplate.new(path)
    output = template.render(data)

    @title = t(:'system/debugging/emailpreview/title', :filename => filename)
    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/debugging/emailpreview', :layout => false, :locals => {
        :title => @title,
        :filename => filename,
        :type => type,
        :data => data,
        :output => output,
      })
    end
  end
end
