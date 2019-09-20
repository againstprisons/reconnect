class ReConnect::Controllers::SystemIndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:access")

    @title = t(:'system/title')
    @to_action = ReConnect::Models::Correspondence
      .where({
        :sent => 'no',
        :actioning_user => nil,
      })
      .map(&:get_data)
      .reject{|x| x[:actioned]}

    @duplicates = ReConnect::Models::PenpalDuplicate.map do |dup|
      prn = dup.decrypt(:prisoner_number)
      penpals = dup.decrypt(:duplicate_ids).split(',').map(&:to_i).map do |pp|
        pp = ReConnect::Models::Penpal[pp]
        next nil unless pp

        name = pp.get_name
        name = name.map{|x| x == "" ? nil : x}.compact.join(" ")
        pseudonym = pp.get_pseudonym
        pseudonym = nil if pseudonym&.empty?

        {
          :name => name,
          :pseudonym => pseudonym,
          :id => pp.id,
        }
      end.compact

      {
        :prisoner_number => prn,
        :penpals => penpals,
      }
    end

    admin_pid = ReConnect.app_config['admin-profile-id']&.to_i
    @admin_profile = ReConnect::Models::Penpal[admin_pid]
    @admin_profile_d = nil
    if @admin_profile
      to_action = ReConnect::Models::Correspondence
        .where({
          :sent => 'to_outside',
          :receiving_penpal => @admin_profile.id,
          :actioning_user => nil,
        })
        .map(&:get_data)
        .reject{|x| x[:actioned]}

      @admin_profile_d = {
        :id => @admin_profile.id,
        :name => @admin_profile.get_name.map{|x| x == "" ? nil : x}.compact.join(" "),
        :to_action => to_action,
      }
    end

    @relationship_count = ReConnect::Models::PenpalRelationship.count
    if @admin_profile
      @relationship_count -= ReConnect::Models::PenpalRelationship.where(:penpal_one => @admin_profile.id).count
      @relationship_count -= ReConnect::Models::PenpalRelationship.where(:penpal_two => @admin_profile.id).count
    end

    @unconfirmed = ReConnect::Models::PenpalRelationship.where(:confirmed => false).map do |pr|
      one = ReConnect::Models::Penpal[pr.penpal_one]
      next nil unless one

      two = ReConnect::Models::Penpal[pr.penpal_two]
      next nil unless two

      {
        :rid => pr.id,
        :penpal_one => {
          :id => one.id,
          :name => one.get_name.map{|x| x&.empty?() ? nil : x}.compact.join(" "),
          :pseudonym => one.get_pseudonym,
        },
        :penpal_two => {
          :id => two.id,
          :name => two.get_name.map{|x| x&.empty?() ? nil : x}.compact.join(" "),
          :pseudonym => two.get_pseudonym,
        },
      }
    end

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/index', :layout => false, :locals => {
        :title => @title,
        :to_action => @to_action,
        :duplicates => @duplicates,
        :admin_profile => @admin_profile_d,
        :unconfirmed => @unconfirmed,
        :counts => {
          :penpals => ReConnect::Models::Penpal.count,
          :relationships => @relationship_count,
          :correspondence => ReConnect::Models::Correspondence.count,
        },
      })
    end
  end
end
