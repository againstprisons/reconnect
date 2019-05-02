class ReConnect::Controllers::SystemPrisonCreateController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:prison:create")

    @title = t(:'system/prison/create/title')

    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/prison/create', :layout => false, :locals => {
          :title => @title,
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

    @prison = ReConnect::Models::Prison.new
    @prison.save
    @prison.encrypt(:name, p_name)
    @prison.encrypt(:physical_address, p_address)
    @prison.encrypt(:email_address, p_email)
    @prison.save

    flash :success, t(:'system/prison/create/success', :id => @prison.id)
    return redirect to("/system/prison/#{@prison.id}")
  end
end

