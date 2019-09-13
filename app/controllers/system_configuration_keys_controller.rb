class ReConnect::Controllers::SystemConfigurationKeysController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemConfigurationHelpers

  add_route :get, "/"
  add_route :get, "/new-key", :method => :new_key
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

  def new_key
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:access") || has_role?("system:configuration:edit")

    return redirect to("/system/configuration/keys/#{request.params["key"]}")
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
    unless %w[bool text number json].include?(type)
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

    if entry.nil?
      entry = ReConnect::Models::Config.new(:key => key)
    end

    entry.type = type
    entry.value = value
    entry.save

    # push key name to the list of pending refreshes
    if ReConnect::APP_CONFIG_ENTRIES.key?(key) && !(%w[maintenance].include?(key))
      unless ReConnect.app_config_refresh_pending.include?(key)
        ReConnect.app_config_refresh_pending << key
        session[:we_changed_app_config] = true
      end
    end

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

    # push key name to the list of pending refreshes
    if ReConnect::APP_CONFIG_ENTRIES.key?(key) && !(%w[maintenance].include?(key))
      unless ReConnect.app_config_refresh_pending.include?(key)
        ReConnect.app_config_refresh_pending << key
        session[:we_changed_app_config] = true
      end
    end

    flash :success, t(:'system/configuration/key_value/edit_key/delete/success', :key => key)
    return redirect to("/system/configuration/keys")
  end
end
