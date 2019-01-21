class ReConnect::Controllers::SystemConfigurationKeysController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemConfigurationHelpers

  add_route :get, "/"
  add_route :get, "/:key", :method => :key_edit
  add_route :post, "/:key", :method => :key_edit
  add_route :post, "/:key/delete", :method => :key_delete

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:access") || has_role?("system:configuration:edit")

    @title = t(:'system/configuration/key_value/title')
    @entries = config_keyvalue_entries

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/configuration/keyvalue/list', :layout => false, :locals => {
        :title => @title,
        :entries => @entries,
      })
    end
  end

  def key_edit(key)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:edit")

    key = key.strip.downcase

    @title = t(:'system/configuration/key_value/edit_key/title', :key => key)
    entry = ReConnect::Models::Config.where(:key => key).first

    value = ""
    value = entry.value if entry

    type = "text"
    type = entry.type if entry

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/configuration/keyvalue/edit', :layout => false, :locals => {
          :title => @title,
          :key => key,
          :is_new => entry.nil?,
          :type => type,
          :value => value,
          :delete_url => "/system/configuration/keys/#{key}/delete",
        })
      end
    end

    type = request.params["type"]&.strip&.downcase
    unless %w[bool text].include?(type)
      flash :error, t(:'system/configuration/key_value/edit_key/type/invalid')
      return redirect request.path
    end

    value = request.params["value"]&.strip
    if type == "bool" 
      value = value.downcase

      unless %w[yes no].include?(value.downcase)
        flash :error, t(:'system/configuration/key_value/edit_key/value/not_bool')
        return redirect request.path
      end
    end

    entry.type = type
    entry.value = value
    entry.save

    ReConnect.app_config_refresh_pending = true

    flash :success, t(:'system/configuration/key_value/edit_key/success', :key => key)
    redirect request.path
  end

  def key_delete(key)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:edit")

    key = key.strip.downcase
    entry = ReConnect::Models::Config.where(:key => key).first

    unless entry
      flash :error, t(:'system/configuration/key_value/edit_key/delete/invalid')
      return redirect to("/system/configuration/keys/#{key}")
    end

    unless request.params["confirm"]&.strip&.downcase == "on"
      flash :error, t(:'system/configuration/key_value/edit_key/delete/confirm_not_checked')
      return redirect to("/system/configuration/keys/#{key}")
    end

    entry.delete
    ReConnect.app_config_refresh_pending = true

    flash :success, t(:'system/configuration/key_value/edit_key/delete/success', :key => key)
    return redirect to("/system/configuration/keys")
  end
end
