class ReConnect::Controllers::IndexController < ReConnect::Controllers::ApplicationController
  add_route :get, "/"

  def index
    @title = t(:'index/title')

    haml :'index/index', :locals => {
      :title => @title,
    }
  end
end
