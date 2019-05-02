class ReConnect::Controllers::SystemPrisonEditController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"
  add_route :post, "/delete", :method => :delete

  def index(pid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:prison:edit")

    @prison = ReConnect::Models::Prison[pid.to_i]
    return halt 404 unless @prison

    @prison_name = @prison.decrypt(:name)
    @prison_address = @prison.decrypt(:physical_address)
    @prison_email = @prison.decrypt(:email_address)
    @title = t(:'system/prison/edit/title', :name => @prison_name)

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/prison/edit', :layout => false, :locals => {
          :title => @title,
          :prison_id => @prison.id,
          :prison_name => @prison_name,
          :prison_address => @prison_address,
          :prison_email => @prison_email,
        })
      end
    end

    p_name = request.params["name"]&.strip
    if p_name.nil? || p_name.empty?
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    p_address = request.params["address"]&.strip
    p_email = request.params["email"]&.strip&.downcase
    if p_email.nil? || p_email.empty?
      flash :error, t(:'required_field_missing')
      return redirect request.path
    end

    @prison.encrypt(:name, p_name)
    @prison.encrypt(:physical_address, p_address)
    @prison.encrypt(:email_address, p_email)
    @prison.save

    flash :success, t(:'system/prison/edit/success')
    return redirect request.path
  end

  def delete(pid)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:prison:edit")

    @prison = ReConnect::Models::Prison[pid.to_i]
    return halt 404 unless @prison

    unless request.params["confirm"]&.strip&.downcase == "on"
      flash :error, t(:'system/prison/delete/confirm_not_checked')
      return redirect to("/system/prison/#{@prison.id}")
    end

    @prison_id = @prison.id
    @prison_name = @prison.decrypt(:name)

    ids = ReConnect::Models::PenpalFilter.perform_filter("prison", @prison.id).map(&:penpal_id).uniq
    if ids.count.positive?
      flash :error, t(:'system/prison/delete/refusing_as_penpals_exist', :count => ids.count)
      return redirect to("/system/prison/#{@prison.id}")
    end

    @prison.delete!
    flash :success, t(:'system/prison/delete/success', :name => @prison_name, :id => @prison_id)
    return redirect to("/system/prison")
  end
end
