module ReConnect::Helpers::PenpalWaitingHelpers
  def get_waiting_penpals
    waiting_status = ReConnect.app_config['penpal-status-waiting-for-relationships']
    return [] if waiting_status.nil? || waiting_status.empty?

    ReConnect::Models::PenpalFilter.perform_filter('status', waiting_status).map do |pf|
      pp = pf.penpal
      next nil if pp.intro.nil?
      intro = pp.decrypt(:intro)
      next nil if intro.nil? || intro.strip.empty?

      {
        :id => pp.id,
        :name => pp.get_pseudonym,
        :intro => intro,
      }
    end.compact
  end
end
