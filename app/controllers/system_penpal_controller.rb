class ReConnect::Controllers::SystemPenpalController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/by-id", :method => :by_id
  add_route :post, "/search", :method => :search
  add_route :get, "/clear-copied", :method => :clear_copied

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @title = t(:'system/penpal/title')

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/index', :layout => false, :locals => {
        :title => @title,
      })
    end
  end

  def by_id
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    id = request.params["id"]&.strip.to_i
    if id.zero?
      flash :error, t(:'system/penpal/search/failed')
      return redirect to('/system/penpal')
    end

    penpal = ReConnect::Models::Penpal[id]
    unless penpal
      flash :error, t(:'system/penpal/search_failed')
      return redirect to('/system/penpal')
    end

    redirect to("/system/penpal/#{penpal.id}")
  end

  def search
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    @title = t(:'system/penpal/search/results/title')

    search_type = request.params["type"]&.strip&.downcase
    search_term = request.params["search"]&.strip&.downcase
    if search_type.nil? || search_type.empty? || search_term.nil? || search_term.empty?
      flash :error, t(:'system/penpal/search/failed')
      return redirect to('/system/penpal')
    end

    ids = ReConnect::Models::PenpalFilter.perform_filter(search_type, search_term).map(&:penpal_id).uniq
    if ids.count.zero?
      flash :error, t(:'system/penpal/search/failed')
      return redirect to('/system/penpal')
    end

    penpals = ids.map{|id| ReConnect::Models::Penpal[id]}.compact.sort{|a, b| a.id <=> b.id}
    if penpals.count.zero?
      flash :error, t(:'system/penpal/search/failed')
      return redirect to('/system/penpal')
    end

    # go directly to penpal page if only one penpal was found
    if penpals.count == 1
      return redirect to("/system/penpal/#{penpals.first.id}")
    end

    @penpals = penpals.map do |pp|
      {
        :id => pp.id,
        :name => pp.get_name,
        :link => url("/system/penpal/#{pp.id}"),
      }
    end

    # if multiple are found, render a search results page
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/penpal/search_results', :layout => false, :locals => {
        :title => @title,
        :penpals => @penpals,
      })
    end
  end

  def clear_copied
    session.delete(:copied_penpal_id)
    redirect back
  end
end
