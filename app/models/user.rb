class ReConnect::Models::User < Sequel::Model
  one_to_many :user_roles
  one_to_many :tokens

  def password=(pw)
    self.password_hash = ReConnect::Crypto.password_hash(pw)
  end

  def password_correct?(pw)
    ReConnect::Crypto.password_verify(self.password_hash, pw)
  end

  def login!
    token = ReConnect::Models::Token.generate
    token.user = self
    token.use = "session"
    token.save

    token
  end

  def invalidate_all_tokens_except!(token)
    self.tokens.reject{|x| x.token == token.token}.map(&:invalidate!)
  end
end
