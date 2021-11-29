class ReConnect::Controllers::HolidayCardController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::HolidayCardHelpers

  add_route :get, '/:instance', method: :index
  add_route :post, '/:instance', method: :index
  add_route :get, '/:instance/write/:ppid', method: :write_choose_cover
  add_route :get, '/:instance/write/:ppid/c:coverid', method: :write_compose
  add_route :post, '/:instance/write/:ppid/c:coverid', method: :write_compose

  def before
    unless logged_in?
      session[:after_login] = request.path
      flash :error, t(:must_log_in)
      return redirect to("/auth")
    end
  end

  def index(instance)
    @instance = ReConnect.app_config['correspondence-card-instances'][instance]
    return halt 404 unless @instance && @instance["enabled"]

    @manual_mode = false
    @count_field = :online_count
    if has_role?("holidaycard:manual:access")
      @manual_mode = request.params['manual']&.strip.to_i.positive?
      if @manual_mode
        @count_field = :manual_count
      end
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

  def write_choose_cover(instance, ppid)
    @instance = ReConnect.app_config['correspondence-card-instances'][instance]
    return halt 404 unless @instance && @instance["enabled"]
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @pp_cobj = ReConnect::Models::HolidayCardCount.where(card_instance: instance, penpal_id: ppid).first
    return halt 404 unless @pp_cobj
    @relationship = @pp_cobj.get_relationship
    return halt 404 unless @relationship

    @penpal_pseudonym = @penpal.get_pseudonym
    @covers = ReConnect::Models::HolidayCardCover.where(enabled: true).all
    @title = t(:'holidaycard/write/title', name: @penpal_pseudonym)

    haml :'holidaycard/write/cover', locals: {
      title: @title,
      instance: @instance,
      instance_name: instance,
      penpal: @penpal,
      penpal_pseudonym: @penpal_pseudonym,
      covers: @covers,
    }
  end

  def write_compose(instance, ppid, coverid)
    @instance = ReConnect.app_config['correspondence-card-instances'][instance]
    return halt 404 unless @instance && @instance["enabled"]
    @penpal = ReConnect::Models::Penpal[ppid.to_i]
    return halt 404 unless @penpal
    @pp_cobj = ReConnect::Models::HolidayCardCount.where(card_instance: instance, penpal_id: ppid).first
    return halt 404 unless @pp_cobj
    @relationship = @pp_cobj.get_relationship
    return halt 404 unless @relationship
    @cover = ReConnect::Models::HolidayCardCover[coverid.to_i]
    return halt 404 unless @cover && @cover.enabled

    @penpal_pseudonym = @penpal.get_pseudonym
    @title = t(:'holidaycard/write/title', name: @penpal_pseudonym)

    force_compose = request.params["compose"]&.strip&.downcase == "1"
    content = nil
    if request.post?
      content = request.params["content"]&.strip
      content = nil if content&.empty?

      if content.nil? || content&.empty?
        flash :error, t(:'holidaycard/write/compose/errors/no_text')
        force_compose = true
      end
    end

    if request.get? || force_compose
      return haml(:'holidaycard/write/compose', locals: {
        title: @title,
        instance: @instance,
        instance_name: instance,
        cover: @cover,
        cobj: @pp_cobj,
        penpal: @penpal,
        penpal_pseudonym: @penpal_pseudonym,
        content: content,
      })
    end

    # Remove invalid characters and do a sanitize run
    content.gsub!(/[^[:print:]]/, "\uFFFD")
    content = Sanitize.fragment(content, Sanitize::Config::RELAXED)

    # Either show confirmation screen, or submit correspondence
    confirmed = request.params["confirm"]&.strip&.downcase == "1"
    unless confirmed
      return haml(:'holidaycard/write/compose_confirm', locals: {
        title: @title,
        instance: @instance,
        instance_name: instance,
        cover: @cover,
        cobj: @pp_cobj,
        penpal: @penpal,
        penpal_pseudonym: @penpal_pseudonym,
        content: content,
      })
    end

    # Save as file object
    obj = ReConnect::Models::File.upload(content, filename: "#{DateTime.now.strftime("%Y-%m-%d_%H%M%S")}.html")
    obj.mime_type = "text/html"
    obj.save

    # create the correspondence
    c = ReConnect::Models::Correspondence.new
    c.creation = Time.now
    c.creating_user = current_user.id
    c.file_id = obj.file_id
    c.sending_penpal = @instance["penpal_id"].to_i
    c.receiving_penpal = @penpal.id
    c.card_instance = instance
    c.card_cover = @cover.id
    c.card_status = 'ready'
    c.save

    ReConnect::Workers::CorrespondenceCardGenerateWorker.perform_async(c)

    @pp_cobj.update(online_count: (@pp_cobj.online_count + 1))

    flash :success, t(:'holidaycard/write/compose/success', name: @penpal_pseudonym)
    return redirect "/hcard/#{instance}"
  end
end
