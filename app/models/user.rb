require 'addressable'

class ReConnect::Models::User < Sequel::Model
  one_to_many :user_roles
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

  def delete!
    self.penpal&.delete!
    self.penpal_id = nil

    self.tokens.map(&:delete)
    self.user_roles.map(&:delete)

    self.delete
  end
end
