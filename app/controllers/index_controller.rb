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

      {
        :id => other.id,
        :name => other.get_name,
      }
    end.compact

    @new_received = ReConnect::Models::Correspondence.where(:receiving_penpal => @current_penpal.id, :actioning_user => nil).map do |c|
      next if c.nil?

      sending = ReConnect::Models::Penpal[c.sending_penpal]

      {
        :id => c.id,
        :creation => c.creation,

        :sending_penpal => sending,
        :sending_penpal_name => sending.get_name,
        :receiving_penpal => @current_penpal,
        :receiving_penpal_name => @current_penpal.get_name,

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
