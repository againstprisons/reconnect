module ReConnect::Route
  @@mine = {}

  def self.all_routes
    @@mine
  end

  def my
    @@mine[inspect.to_sym] ||= {
      :routes => []
    }
  end

  def my=(r)
    @@mine[inspect.to_sym] = r
  end

  def add_route(verb, path, opts = {})
    verb = verb.to_s.upcase
    meth = opts[:method] ||= :index

    controller_entry = ReConnect::Controllers.active_controllers.select do |b|
      b[:controller] == inspect.split("::").last
    end.first

    path = "" if path == "/"
    full_path = "#{controller_entry[:path]}#{path}"

    my[:routes] << {
      :verb => verb,
      :method => meth,
      :path => {
        :full => full_path,
        :fragment => path,
      }
    }

    this = self
    ReConnect::Application.class_eval do
      route(verb, full_path, {}) do |*args|
        controller = this.new(self)
        controller.before() if controller.respond_to?(:before)
        next controller.send(meth, *args)
      end
    end
  end
end
