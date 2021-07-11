require 'addressable'

class ReConnect::Models::User < Sequel::Model
  one_to_many :user_roles
  one_to_many :user_groups
  one_to_many :tokens
  one_to_one :penpal

  def get_name
    [self.decrypt(:first_name), self.decrypt(:last_name)]
  end

  def get_pseudonym
    p = self.decrypt(:pseudonym)
    return self.get_name.first if p.nil? || p.empty?
    p
  end

  def password=(pw)
    self.password_hash = ReConnect::Crypto.password_hash(pw)
  end

  def password_correct?(pw)
    return false if self.password_hash.nil?
    return false if self.password_hash&.empty?

    ReConnect::Crypto.password_verify(self.password_hash, pw)
  end

  def password_reset!
    token = ReConnect::Models::Token.generate
    token.use = "password_reset"
    token.expiry = Time.now + (60 * 60) # 1 hour
    token.user_id = self.id
    token.save

    url = Addressable::URI.parse(ReConnect.app_config["base-url"])
    url += "/auth/reset/#{token.token}"

    data = {
      :email_address => self.email,
      :reset_link => url.to_s,
    }

    email = ReConnect::Models::EmailQueue.new_from_template("password_reset", data)
    email.queue_status = "queued"
    email.encrypt(:subject, "Password reset") # TODO: translation
    email.encrypt(:recipients, JSON.dump({"mode" => "list", "list" => [self.email]}))
    email.save

    [token, email]
  end

  def login!
    token = ReConnect::Models::Token.generate
    token.user = self
    token.use = "session"
    token.save

    token
  end

  def invalidate_tokens!
    invalidate_tokens_except!(nil)
  end 

  def invalidate_tokens_except!(token)
    to_invalidate = self.tokens
    unless token.nil?
      token = token.token if token.respond_to?(:token)
      to_invalidate.reject!{|x| x.token == token}
    end

    to_invalidate.map(&:invalidate!)
  end

  def ip_ban_from_tokens!(banning_user)
    banning_user = banning_user.id if banning_user.respond_to?(:id)

    ReConnect::Models::EmailBlock.new({
      email: self.email,
      is_domain: false,
      reason: "User#ip_ban_from_tokens! on User[#{self.id}] (#{self.get_name.join(' ')}) (#{self.email})",
      creator: banning_user,
    }).save

    self.tokens.map do |token|
      next nil unless token.use == 'session'

      if !(token.extra_data.nil?())
        begin
          token_data = JSON.parse(token.extra_data)

          next nil if ReConnect::Models::IpBlock
            .where(ip_address: token_data['ip_address'])
            .count
            .positive?

          ReConnect::Models::IpBlock.new({
            ip_address: token_data['ip_address'],
            reason: "User#ip_ban_from_tokens! on User[#{self.id}] (#{self.get_name.join(' ')}) (#{self.email})",
            creator: banning_user,
          }).save
        rescue
          next nil
        end
      end
    end.compact
  end

  def delete!
    self.penpal&.delete!
    self.penpal_id = nil

    self.tokens.map(&:delete)
    self.user_roles.map(&:delete)

    my_name = self.get_name.join(' ')
    ReConnect::Models::VolunteerRosterEntry.where(user_id: self.id).each do |vre|
      vre.user_id = nil
      vre.user_name = my_name
      vre.save
    end

    self.delete
  end
end
