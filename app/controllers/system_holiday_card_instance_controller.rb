class ReConnect::Controllers::SystemHolidayCardInstanceController < ReConnect::Controllers::ApplicationController
  add_route :get, '/', method: :index

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?('system:holidaycard:instance:access')
  end

  def index(iname)
    @instance = ReConnect.app_config['correspondence-card-instances'][iname]
    return halt 404 unless @instance
    @title = t(:'system/holidaycard/instance_index/title', friendly: @instance["friendly"])

    haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/holidaycard/instance_index', layout: false, locals: {
        title: @title,
        instance_name: iname,
        instance: @instance,
        card_count: ReConnect::Models::Correspondence.where(card_instance: iname).count,
        card_printed_count: ReConnect::Models::Correspondence.where(card_instance: iname, sent: 'card_printed').count,
      })
    end
  end
end
