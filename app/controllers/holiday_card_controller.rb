class ReConnect::Controllers::HolidayCardController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::HolidayCardHelpers

  add_route :get, '/:instance', method: :index
  add_route :post, '/:instance', method: :index

  def before
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end
  end

  def index(instance)
    @instance = ReConnect.app_config['correspondence-card-instances'][instance]
    return halt 404 unless @instance

    @manual_mode = false
    @count_field = :online_count
    if has_role?("holidaycard:manual:access")
      @manual_mode = request.params['manual']&.strip.to_i.positive?
      @count_field = :manual_count
    end

    if @manual_mode && request.post?
      penpal_ids = (request.params['penpals'] || '').strip.split(',').map(&:to_i)
      if penpal_ids.empty?
        flash :error, t(:'holidaycard/index/manual_mode/errors/unknown_error')
        return redirect request.path
      end

      penpal_ids.each do |ppid|
        count = request.params["mcu__#{ppid}"]&.strip.to_i
        cobj = ReConnect::Models::HolidayCardCount.where({
          card_instance: instance,
          penpal_id: ppid,
        }).first

        cobj.update({ @count_field => cobj[@count_field] + count })
      end

      flash :success, t(:'holidaycard/index/manual_mode/success')
    end

    @title = t(:'holidaycard/index/title', instance_name: @instance["friendly"])
    @penpals = holidaycard_penpal_list(instance, count_field: @count_field)

    haml :'holidaycard/index', locals: {
      title: @title,
      penpals: @penpals,
      manual_mode: @manual_mode,
      instance_name: instance,
      instance: @instance,
    }
  end
end
