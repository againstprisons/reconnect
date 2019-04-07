module ReConnect::Helpers::SystemJobQueueHelpers
  def job_queue_available_jobs
    ReConnect::Workers.constants.map do |sym|
      m = ReConnect::Workers.const_get(sym)
      next nil unless m.respond_to?(:perform_async)

      [
        sym.to_s,
        {
          :sym => sym,
          :worker => m,
        }
      ]
    end.compact.to_h
  end
end
