class ReConnect::Controllers::SystemJobQueueController < ReConnect::Controllers::ApplicationController
  include ReConnect::Helpers::SystemJobQueueHelpers

  add_route :get, "/"
  add_route :post, "/queue", :method => :queue

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:job_queue")

    @title = t(:'system/job_queue/title')
    @jobs = job_queue_available_jobs

    return haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/job_queue/index', :layout => false, :locals => {
        :title => @title,
        :jobs => @jobs,
      })
    end
  end

  def queue
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:job_queue")

    @jobs = job_queue_available_jobs

    # verify requested job exists
    job_name = request.params["job_name"]&.strip
    if job_name.nil? || job_name.empty? || !(@jobs.keys.include?(job_name))
      flash :error, t(:'system/job_queue/errors/invalid_job')
      return redirect url('/system/jobqueue')
    end
    @job = @jobs[job_name]

    # verify data
    job_data = request.params["job_data"]&.strip
    if job_data.nil? || job_data.empty?
      flash :warning, t(:'system/job_queue/warnings/no_data_using_empty')
      job_data = '[]'
    end

    # decode job data
    begin
      job_json = JSON.parse(job_data)
    rescue => e
      flash :error, t(:'system/job_queue/errors/invalid_data')
      return redirect url('/system/jobqueue')
    end

    job_id = @job[:worker].perform_async(*job_json)
    flash :success, t(:'system/job_queue/success', :job_name => job_name, :job_id => job_id)
    return redirect to('/system/jobqueue')
  end
end
