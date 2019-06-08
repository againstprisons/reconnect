class ReConnect::Controllers::SystemConfigurationFilterController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemConfigurationFilterHelpers

  add_route :get, "/"
  add_route :post, "/remove-word", :method => :remove_word
  add_route :post, "/add-word", :method => :add_word

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:filter")

    @title = t(:'system/configuration/filter/title')

    @words = filter_get_db_words()
    if @words[:err]
      if %i[noentry].include? @words[:err]
        flash :warning, t(:'system/configuration/filter/words/warnings/no_config_entry')
      elsif %i[parse parsed_nil].include? @words[:err]
        flash :warning, t(:'system/configuration/filter/words/warnings/unable_to_parse')
      else
        flash :warning, t(:'system/configuration/filter/words/warnings/unknown_error')
      end
    end

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/configuration/filter', :layout => false, :locals => {
        :title => @title,
        :words => @words[:val],
      })
    end
  end

  def remove_word
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:filter")

    @words = filter_get_db_words()
    @words = @words[:val] # ignore error

    word = request.params["word"]&.strip&.downcase
    if word.nil? || word.empty?
      flash :error, t(:'system/configuration/filter/words/remove/error/no_word')
      return redirect back
    end

    unless @words.include? word
      flash :error, t(:'system/configuration/filter/words/remove/error/not_in_list', :word => word)
      return redirect back
    end

    @words.compact!
    @words.delete(word)

    dumped_json = JSON.dump(@words)

    # save to config
    m = ReConnect::Models::Config.find_or_create(:key => 'filter-words') do |a|
      a.type = 'text'
    end

    m.value = dumped_json
    m.save

    # indicate we need a reload
    unless ReConnect.app_config_refresh_pending.include?('filter-words')
      ReConnect.app_config_refresh_pending << 'filter-words'
    end

    flash :success, t(:'system/configuration/filter/words/remove/success', :word => word)
    return redirect back
  end

  def add_word
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:configuration:filter")

    @words = filter_get_db_words()
    @words = @words[:val] # ignore error

    word = request.params["word"]&.strip&.downcase
    if word.nil? || word.empty?
      flash :error, t(:'system/configuration/filter/words/add/error/no_word')
      return redirect back
    end

    if @words.include? word
      flash :error, t(:'system/configuration/filter/words/add/error/exists', :word => word)
      return redirect back
    end

    @words.compact!
    @words << word

    dumped_json = JSON.dump(@words)

    # save to config
    m = ReConnect::Models::Config.find_or_create(:key => 'filter-words') do |a|
      a.type = 'text'
    end

    m.value = dumped_json
    m.save

    # indicate we need a reload
    unless ReConnect.app_config_refresh_pending.include?('filter-words')
      ReConnect.app_config_refresh_pending << 'filter-words'
    end

    flash :success, t(:'system/configuration/filter/words/add/success', :word => word)
    return redirect back
  end
end
