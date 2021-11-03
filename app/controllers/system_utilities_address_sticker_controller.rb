require 'csv'

class ReConnect::Controllers::SystemUtilitiesAddressStickerController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"
  add_route :get, "/job/:jid", method: :job_index
  add_route :get, "/job/:jid/download", method: :job_download
  add_route :post, "/job/:jid/archive", method: :job_archive
  add_route :post, "/create/-/search", method: :create_search
  add_route :post, "/create/-/csv", method: :create_csv
  add_route :get, "/create/:fid", method: :create_verify
  add_route :post, "/create/:fid", method: :create_verify

  include ReConnect::Helpers::SystemPenpalSearchHelpers

  def before(*args)
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:utilities:address_sticker")
  end

  def index
    # Get current user's address sticker jobs
    @my_jobs = ReConnect::Models::AddressStickerJob
      .where(user_id: current_user.id, deleted: false)
      .all
    @my_jobs.map! do |job|
      {
        id: job.id,
        created: job.created,
        status: job.status,
        page_type: job.page_type,
        file_id: job.file_id,
      }
    end

    @title = t(:'system/utilities/address_sticker/title')
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/utilities/address_sticker/index', :layout => false, :locals => {
        title: @title,
        my_jobs: @my_jobs,
      })
    end
  end

  def job_index(jid)
    @job = ReConnect::Models::AddressStickerJob[jid.to_i]
    return halt 404 unless @job
    return halt 404 unless @job.user_id == current_user.id

    @title = t(:'system/utilities/address_sticker/job_view/title', jid: @job.id)
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/utilities/address_sticker/job/index', :layout => false, :locals => {
        title: @title,
        job: @job,
      })
    end
  end

  def job_download(jid)
    @job = ReConnect::Models::AddressStickerJob[jid.to_i]
    return halt 404 unless @job
    return halt 404 unless @job.user_id == current_user.id

    return halt 404 unless @job.file_id
    @file = ReConnect::Models::File.where(file_id: @job.file_id).first
    return halt 404 unless @file

    @token = @file.generate_download_token(current_user)
    return redirect url("/filedl/#{@file.file_id}/#{@token.token}")
  end

  def job_archive(jid)
    @job = ReConnect::Models::AddressStickerJob[jid.to_i]
    return halt 404 unless @job
    return halt 404 unless @job.user_id == current_user.id

    @job.update(deleted: true)
    flash :success, t(:'system/utilities/address_sticker/job_view/archive/success')
    return redirect url("/system/utilities/address-sticker/job/#{@job.id}")
  end

  def create_search
    return halt 404 unless has_role?("system:utilities:address_sticker:search")

    query = request.params['query']&.strip
    query = nil if query.empty?
    return halt 400 unless query

    begin
      id_list = penpal_search_perform(query)
      if id_list.empty?
        flash :error, t(:'system/utilities/address_sticker/create_search/errors/no_results')
        return redirect back
      end

    rescue => ex
      flash :error, t(:'system/utilities/address_sticker/create_search/errors/exception', ex: ex.message)
      return redirect back
    end

    # Create source data JSON from these search results
    prison_addresses = {}
    source_data = id_list.map do |ppid|
      pp = ReConnect::Models::Penpal[ppid]

      name = [
        pp.get_name.join(' '),
        "##{pp.decrypt(:prisoner_number)}",
      ].join(", ")

      pp_prison = pp.decrypt(:prison_id).to_s
      unless prison_addresses.key?(pp_prison)
        prison = ReConnect::Models::Prison[pp_prison.to_i]
        prison_addresses[pp_prison] = prison&.decrypt(:physical_address)
      end
      address = prison_addresses[pp_prison]

      [
        name,
        address,
      ]
    end

    # Upload the source data as JSON
    source_json = JSON.generate(source_data)
    file = ReConnect::Models::File.upload(
      source_json,
      filename: "search_results.json",
      mime_type: 'application/json'
    )

    # Redirect to the verification
    return redirect url("/system/utilities/address-sticker/create/#{file.file_id}")
  end

  def create_csv
    return halt 404 unless has_role?("system:utilities:address_sticker:csv")

    # Grab the filename
    fn = params[:file][:filename]

    # Grab and parse the CSV
    params[:file][:tempfile].rewind
    csv = CSV.new(params[:file][:tempfile].read, headers: true)
    source_data = csv.to_a.map(&:to_h).map(&:values)

    # Upload the source data as JSON
    source_json = JSON.generate(source_data)
    file = ReConnect::Models::File.upload(
      source_json,
      filename: "csv_parse.json",
      mime_type: 'application/json'
    )

    # Redirect to the verification
    return redirect url("/system/utilities/address-sticker/create/#{file.file_id}")
  end

  def create_verify(fid)
    return halt 404 unless has_role?("system:utilities:address_sticker:create")
    @file = ReConnect::Models::File.where(file_id: fid).first

    return halt 404 unless @file
    @data = JSON.parse(@file.decrypt_file)

    layout, okay = [nil, true]
    if request.post?
      layout = request.params['layout']&.strip
      unless ReConnect.app_config['stickersheet-layouts'].key?(layout)
        flash :error, t(:'system/utilities/address_sticker/create_verify/errors/no_layout')
        okay = false
      end

      if okay
        obj = ReConnect::Models::AddressStickerJob.new({
          user_id: current_user.id,
          page_type: layout,
          source_file_id: @file.file_id,
        }).save

        ReConnect::Workers::AddressStickerGenerateWorker.perform_async(obj.id)
        return redirect url("/system/utilities/address-sticker/job/#{obj.id}")
      end
    end

    @title = t(:'system/utilities/address_sticker/create_verify/title')
    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/utilities/address_sticker/create/verify', :layout => false, :locals => {
        title: @title,
        data: @data,
        file_id: @file.file_id,
      })
    end
  end
end
