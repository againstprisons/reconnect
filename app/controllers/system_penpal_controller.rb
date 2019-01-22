class ReConnect::Controllers::SystemPenpalController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/by-id", :method => :by_id
  add_route :post, "/by-name", :method => :by_name
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
      flash :error, t(:'system/penpal/search_failed')
      return redirect to('/system/penpal')
    end

    penpal = ReConnect::Models::Penpal[id]
    unless penpal
      flash :error, t(:'system/penpal/search_failed')
      return redirect to('/system/penpal')
    end

    redirect to("/system/penpal/#{penpal.id}")
  end

  def by_name
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:penpal:access")

    flash :error, "unimplemented"
    return redirect to('/system/penpal')

    penpal_name = request.params["name"]&.strip
    if penpal_name.nil? || penpal_name == ""
      flash :error, t(:'system/penpal/search_failed')
      return redirect to('/system/penpal')
    end

    # TODO: search by name once indexing works
    #redirect to("/system/penpal/#{penpal.id}")
  end

  def clear_copied
    session.delete(:copied_penpal_id)
    redirect back
  end
end
