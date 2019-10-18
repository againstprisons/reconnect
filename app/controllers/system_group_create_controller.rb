class ReConnect::Controllers::SystemGroupCreateController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :post, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:group:create")

    @title = t(:'system/group/create/title')
    if request.get?
      return haml(:'system/layout', :locals => {:title => @title}) do
        haml(:'system/group/create', :layout => false, :locals => {
          :title => @title,
        })
      end
    end

    name = request.params['name']&.strip
    if name.nil? || name&.empty?
      flash :error, t(:'system/group/create/errors/no_name')
      return redirect request.path
    end

    @group_names = ReConnect::Models::Group.all.map do |group|
      group.decrypt(:name).strip.downcase
    end

    if @group_names.include? name.strip.downcase
      flash :error, t(:'system/group/create/errors/already_exists')
      return redirect request.path
    end

    gr = ReConnect::Models::Group.new
    gr.save
    gr.encrypt(:name, name)
    gr.requires_2fa = request.params['2fa']&.strip&.downcase == 'on'
    gr.save

    flash :success, t(:'system/group/create/success', :id => gr.id)
    return redirect url("/system/group/#{gr.id}")
  end
end
