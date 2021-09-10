class ReConnect::Workers::PenpalStatusTransitionWorker
  include Sidekiq::Worker

  def perform
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    ReConnect.app_config['penpal-status-transitions'].each do |transition|
      logger.info("transition from:#{transition["from"].inspect} to:#{transition["to"].inspect}")

      modes = [transition["when"]["mode"]].flatten

      last_correspondence_gate = nil
      if modes.include?("last_correspondence")
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
          do_transition = []
          
          if ReConnect.app_config["penpal-allow-status-override"] && pp.status_override
            do_transition << false
          end

          modes.each do |mode|
            case mode
            when "last_correspondence"
              last = ReConnect::Models::Correspondence
                .where(:sending_penpal => pp.id)
                .order(Sequel.desc(:creation))
                .first

              if last
                do_transition << (last.creation < last_correspondence_gate)
              else
                do_transition << false
              end

            when "penpal_count"
              rels = ReConnect::Models::PenpalRelationship
                .find_for_single_penpal(pp)

              # filter out relationships with admin/advocacy profiles
              reject_pids = [
                ReConnect.app_config['admin-profile-id'].to_i,
                ReConnect.app_config['advocacy-profile-id'].to_i,
              ].compact.uniq

              if !reject_pids.empty?
                rels.reject! do |r|
                  other_party = r.penpal_one
                  other_party = r.penpal_two if other_party == pp.id

                  reject_pids.include?(other_party)
                end
              end

              # filter out relationships with soft-deleted users
              rels.reject! do |r|
                other_party = r.penpal_one
                other_party = r.penpal_two if other_party == pp.id

                other_pp = ReConnect::Models::Penpal[other_party]
                other_user = ReConnect::Models::User[other_pp&.user_id]
                if other_user
                  next true if other_user.soft_deleted
                end

                false
              end

              # filter out relationships with override set
              rels.reject!(&:status_override)

              do_transition << (rels.count > transition["when"]["penpal_count"])
            end
          end

          if do_transition.all?
            pp.encrypt(:status, transition["to"])
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
