class ReConnect::Workers::VolunteerRosterReminderWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    [(DateTime.now + 1), (DateTime.now + 2)].map(&:to_date).each do |day|
      vre = ReConnect::Models::VolunteerRosterEntry.where(roster_day: day).first
      next unless vre
      user = vre.user
      next unless user

      alert_data = {
        :name => user.get_name,
        :day => day,
      }

      email = ReConnect::Models::EmailQueue.new_from_template('volunteer_roster_reminder', alert_data)
      email.queue_status = 'queued'
      email.encrypt(:subject, "Volunteer reminder: Mail pickup on #{day.strftime('%A, %-d %B %Y')}")
      email.encrypt(:recipients, JSON.generate({mode: "list", list: [user.email]}))
      email.save

      logger.info("Queued alert email to uid #{user.id} for day #{day.strftime('%Y-%m-%d')} as EmailQueue id #{email.id}")
    end
  end
end
