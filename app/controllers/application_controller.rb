class ReConnect::Controllers::ApplicationController
  extend ReConnect::Route

  def initialize(app)
    @app = app
  end

  def method_missing(meth, *args, &bk)
    @app.instance_eval do
      self.send(meth, *args, &bk)
    end
  end
end
