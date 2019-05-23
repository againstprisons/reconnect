module ReConnect::Helpers::UserHelpers
  def current_token
    return nil unless session.key?(:token)

    t = ReConnect::Models::Token.where(token: session[:token], :use => 'session').first
    return nil unless t
    return nil unless t.check_validity!

    t
  end

  def logged_in?
    !current_token.nil?
  end

  def current_user
    current_token.user
  end

  def current_user_is_disabled?
    return false unless logged_in?
    return false if current_prefix?('/auth') || current_prefix?("/static")
    return true if current_user.disabled_reason != nil
  end

  def current_user_name_or_email
    return nil unless logged_in?
    u = current_user

    name = u.get_name.map{|x| x == "" ? nil : x}.compact
    unless name.empty?
      return "#{name.join(" ")} (#{u.email})"
    end

    u.email
  end

  def has_role?(role, opts = {})
    user = current_user
    if opts[:user]
      user = opts[:user]
    else
      return false unless logged_in?
    end

    parts = role.split(':')
    roleparts = user.user_roles.map do |r|
      r.role.split(':')
    end

    roleparts.each do |rp|
      skip = false
      oksofar = true

      rp.each_index do |rpi|
        next if skip

        if oksofar && rp[rpi] == '*'
          return true
        elsif rp[rpi] != parts[rpi]
          oksofar = false
          skip = true
        end
      end

      return true if oksofar
    end

    false
  end
end
