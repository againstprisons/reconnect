module ReConnect::Helpers::FlashHelpers
  def flash(type, message)
    message = message.force_encoding("UTF-8")
    session[:flash] ||= []
    session[:flash] << {:type => type, :message => message}
  end

  def render_flashes
    return "" unless session[:flash]
    out = []

    session[:flash].each do |f|
      locals = {
        :type => f[:type].to_s.force_encoding("UTF-8"),
        :message => f[:message].force_encoding("UTF-8"),
      }

      out << haml(:flash, :locals => locals)
    end

    session[:flash] = []

    out.join("")
  end
end
