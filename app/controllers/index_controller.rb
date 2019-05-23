class ReConnect::Controllers::IndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    @title = t(:'index/title')

    unless logged_in?
      return haml :'index/index', :locals => {
        :title => @title,
      }
    end

    @current_penpal = ReConnect::Models::Penpal[current_user.penpal_id]

    @penpals = ReConnect::Models::PenpalRelationship.find_for_single_penpal(@current_penpal).map do |pr|
      if pr.penpal_one == @current_penpal.id
        other = ReConnect::Models::Penpal[pr.penpal_two]
      else
        other = ReConnect::Models::Penpal[pr.penpal_one]
      end

      name = other.get_name.first
      name = "(unknown)" if name.nil? || name.empty?

      {
        :id => other.id,
        :name => name,
      }
    end.compact

    @new_received = ReConnect::Models::Correspondence.where(:receiving_penpal => @current_penpal.id, :actioning_user => nil).map do |c|
      next if c.nil?

      sending = ReConnect::Models::Penpal[c.sending_penpal]
      sending_name = sending.get_name.first
      sending_name = "(unknown)" if sending_name.nil? || sending_name&.strip&.empty?
      receiving_name = @current_penpal.get_name.first
      receiving_name = "(unknown)" if receiving_name.nil? || receiving_name&.strip&.empty?

      {
        :id => c.id,
        :creation => c.creation,

        :sending_penpal => sending,
        :sending_penpal_name => sending_name,
        :receiving_penpal => @current_penpal,
        :receiving_penpal_name => receiving_name,

        :actioned => !(c.actioning_user.nil?),
      }
    end.compact.sort{|a, b| b[:creation] <=> a[:creation]}

    haml :'index/logged_in', :locals => {
      :title => @title,
      :penpals => @penpals,
      :new_received => @new_received,
    }
  end
end
