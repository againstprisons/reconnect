class ReConnect::Models::Token < Sequel::Model
  many_to_one :user

  def self.generate
    self.new(token: ReConnect::Crypto.generate_token, valid: true)
  end

  def invalidate!
    self.valid = false
    self.save
  end
end
