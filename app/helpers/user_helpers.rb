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
    return nil unless logged_in?
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

  def role_matches?(query, maybe_matches, opts = {})
    if opts[:reject]
      maybe_matches = maybe_matches.map do |m|
        next nil unless m.start_with?("!")
        m[1..-1]
      end.compact
    end

    query_parts = query.split(':')
    maybe_parts = maybe_matches.map{|x| x.split(':')}

    maybe_parts.each do |rp|
      skip = false
      oksofar = true

      rp.each_index do |rpi|
        next if skip

        if oksofar && rp[rpi] == '*'
          return true
        elsif rp[rpi] != query_parts[rpi]
          oksofar = false
          skip = true
        end
      end

      return true if oksofar
    end

    false
  end

  def has_role?(role, opts = {})
    user = opts[:user] || current_user
    return false unless user

    user_roles = [
      user.user_roles.map(&:role),
      user.user_groups.map do |ug|
        ug.group.group_roles.map(&:role)
      end,
    ].flatten

    if role_matches?(role, user_roles, :reject => true)
      return false
    end

    return role_matches?(role, user_roles)
  end
end
