class ReConnect::Controllers::SystemHolidayCardController < ReConnect::Controllers::ApplicationController
  add_route :get, '/', method: :index

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?('system:holidaycard:access')
  end

  def index
    @title = t(:'system/holidaycard/title')
    @instances = ReConnect.app_config['correspondence-card-instances']

    haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/holidaycard/index', layout: false, locals: {
        title: @title,
        instances: @instances,
      })
    end
  end
end
