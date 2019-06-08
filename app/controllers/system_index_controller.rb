class ReConnect::Controllers::SystemIndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    return halt 404 unless logged_in?
    return halt 404 unless has_role?("system:access")

    @title = t(:'system/title')
    @to_action = []
    if has_role?("system:penpal:access")
      @to_action = ReConnect::Models::Correspondence
        .where(:sent => 'no')
        .map(&:get_data)
        .reject{|x| x[:actioned]}
    end

    haml(:'system/layout', :locals => {:title => @title}) do
      haml(:'system/index', :layout => false, :locals => {
        :title => @title,
        :to_action => @to_action,
        :counts => {
          :penpals => ReConnect::Models::Penpal.count,
          :relationships => ReConnect::Models::PenpalRelationship.count,
          :correspondence => ReConnect::Models::Correspondence.count,
        },
      })
    end
  end
end
