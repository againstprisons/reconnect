class ReConnect::Controllers::SystemHolidayCardInstanceCardController < ReConnect::Controllers::ApplicationController
  add_route :get, '/:ccid', method: :index
  add_route :get, '/:ccid/-/download', method: :download
  add_route :post, '/:ccid/-/mark', method: :mark_printed
  add_route :get, '/-/random', method: :random_card

  def before
    return halt 404 unless logged_in?
    return halt 404 unless has_role?('system:holidaycard:instance:card:access')
  end

  def index(iname, ccid)
    @instance = ReConnect.app_config['correspondence-card-instances'][iname]
    return halt 404 unless @instance
    @cc_obj = ReConnect::Models::Correspondence[ccid.to_i]
    return halt 404 unless @cc_obj && @cc_obj.card_instance == iname
    @penpal = ReConnect::Models::Penpal[@cc_obj.receiving_penpal]
    return halt 404 unless @penpal
    @penpal_pseudonym = @penpal.get_pseudonym

    @title = t(:'system/holidaycard/instance_card/title', {
      instance: @instance["friendly"],
      ccid: @cc_obj.id,
      pseudonym: @penpal_pseudonym
    })

    haml(:'system/layout', locals: {title: @title}) do
      haml(:'system/holidaycard/instance_card', layout: false, locals: {
        title: @title,
        instance_name: iname,
        instance: @instance,
        cc_obj: @cc_obj,
        penpal: @penpal,
        penpal_pseudonym: @penpal_pseudonym,
        urls: {
          dl_url: url("/system/hcard/#{iname}/card/#{@cc_obj.id}/-/download?v=0"),
          view_url: url("/system/hcard/#{iname}/card/#{@cc_obj.id}/-/download?v=1"),
          mark_printed: url("/system/hcard/#{iname}/card/#{@cc_obj.id}/-/mark"),
        },
      })
    end
  end

  def download(iname, ccid)
    @instance = ReConnect.app_config['correspondence-card-instances'][iname]
    return halt 404 unless @instance
    @cc_obj = ReConnect::Models::Correspondence[ccid.to_i]
    return halt 404 unless @cc_obj && @cc_obj.card_instance == iname
    return halt 418 unless @cc_obj.card_status == 'generated'

    @file = ReConnect::Models::File.where(file_id: @cc_obj.card_file_id).first
    return halt 418 unless @file

    @v = request.params['v']&.strip.to_i.positive?() ? 1 : 0
    @token = @file.generate_download_token(current_user)
    redirect url("/filedl/#{@file.file_id}/#{@token.token}?v=#{@v}")
  end

  def mark_printed(iname, ccid)
    @instance = ReConnect.app_config['correspondence-card-instances'][iname]
    return halt 404 unless @instance
    @cc_obj = ReConnect::Models::Correspondence[ccid.to_i]
    return halt 404 unless @cc_obj && @cc_obj.card_instance == iname

    @cc_obj.update(sent: 'card_printed')

    flash :success, t(:'system/holidaycard/instance_card/actions/mark_as_printed/success')
    return redirect back
  end

  def random_card(iname)
    @instance = ReConnect.app_config['correspondence-card-instances'][iname]
    return halt 404 unless @instance

    @card = ReConnect::Models::Correspondence
      .where(sent: 'no', card_instance: iname, card_status: 'generated')
      .order_by(Sequel.lit('RANDOM()'))
      .first

    unless @card
      flash :error, t(:'system/holidaycard/instance_card/random/errors/no_unprinted_cards')
      return redirect url("/system/hcard/#{iname}")
    end

    redirect url("/system/hcard/#{iname}/card/#{@card.id}")
  end
end
