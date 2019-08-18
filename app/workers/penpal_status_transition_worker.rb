class ReConnect::Workers::PenpalStatusTransitionWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(true)

    ReConnect.app_config['penpal-status-transitions'].each do |transition|
      logger.info("transition from:#{transition["from"].inspect} to:#{transition["to"].inspect}")

      last_correspondence_gate = nil
      if transition["when"]["mode"] == "last_correspondence"
        last_correspondence_gate = Chronic.parse(transition["when"]["last_correspondence"], :guess => true)
      end

      # get penpals that have the 'from' status
      from_pps = ReConnect::Models::PenpalFilter
        .perform_filter('status', transition["from"])
        .map(&:penpal_id)
        .uniq
        .map{|id| ReConnect::Models::Penpal[id]}
        .select{|x| x.is_incarcerated == true}

      logger.info("Potentials for this transition: #{from_pps.count}")
      count = {:processed => 0, :ok => 0, :error => 0}

      from_pps.each do |pp|
        count[:processed] += 1
        if (count[:processed] % 10) == 0
          logger.info("#{count[:processed]} checked so far")
        end

        begin
          changed = false
          if transition["when"]["mode"] == "last_correspondence"
            last = ReConnect::Models::Correspondence
              .where(:sending_penpal => pp.id)
              .order(Sequel.desc(:creation))
              .first

            if last
              if last.creation < last_correspondence_gate
                # do the transition
                pp.encrypt(:status, transition["to"])
                changed = true
              end
            end
          end

          if changed
            pp.save
            ReConnect::Models::PenpalFilter.clear_filters_for(pp)
            ReConnect::Models::PenpalFilter.create_filters_for(pp)
          end

          count[:ok] += 1
        rescue => e
          count[:error] += 1

          errmsg = "Penpal #{pp.id} errored - #{e.class.name}: #{e}\n"
          errmsg += "Traceback: #{e.traceback}" if e.respond_to?(:traceback)
          logger.error(errmsg)
        end
      end

      logger.info("Done: #{count[:ok]} okay, #{count[:error]} errored")
    end
  end
end
