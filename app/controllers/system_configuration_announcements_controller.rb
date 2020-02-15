class ReConnect::Controllers::SystemConfigurationAnnouncementsController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/create", :method => :create
  add_route :post, "/delete", :method => :delete
  add_route :post, "/toggle", :method => :toggle
  
  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:announcements")

    @title = t(:'system/configuration/announcements/title')
    @all_announcements = ReConnect::Models::Announcement.order(Sequel.desc(:created)).all
    
    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/configuration/announcements', :layout => false, :locals => {
        :title => @title,
        :announcements => @all_announcements,
      })
    end
  end
  
  def create
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:announcements:create")
    
    message = request.params['message']&.strip
    only_logged_in = request.params['only_logged_in']&.strip&.downcase == 'on'
    
    if message.nil? || message.empty?
      flash :error, t(:'system/configuration/announcements/create/no_message')
      return redirect to("/system/configuration/announcements")
    end
    
    # escape message
    message = ERB::Util.html_escape(message)
    
    # create announcement
    announcement = ReConnect::Models::Announcement.new
    announcement.message = message
    announcement.only_logged_in = only_logged_in
    announcement.valid = false # explicitly disable this announcement, requiring a manual enable
    announcement.save

    flash :success, t(:'system/configuration/announcements/create/success', :id => announcement.id)
    redirect to("/system/configuration/announcements")
  end
  
  def delete
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:announcements:modify")

    announcement = ReConnect::Models::Announcement[request.params["id"].to_i]
    return halt 404 unless announcement
    anid = announcement.id
    announcement.delete

    flash :success, t(:'system/configuration/announcements/delete/success', :id => anid)
    redirect to("/system/configuration/announcements")
  end
  
  def toggle
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:announcements:modify")

    announcement = ReConnect::Models::Announcement[request.params["id"].to_i]
    return halt 404 unless announcement
    announcement.valid = !announcement.valid
    announcement.save

    if announcement.valid
      flash :success, t(:'system/configuration/announcements/toggle/success_enabled', :id => announcement.id)
    else
      flash :success, t(:'system/configuration/announcements/toggle/success_disabled', :id => announcement.id)
    end

    redirect to("/system/configuration/announcements")
  end
end
