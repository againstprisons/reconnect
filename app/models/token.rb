class ReConnect::Models::Token < Sequel::Model
  many_to_one :user

  def self.generate
    self.new(token: ReConnect::Crypto.generate_token, valid: true, creation: Time.now, expiry: nil)
  end

  def check_validity!
    return false unless self.valid

    if self.expiry && Time.now >= self.expiry
      self.invalidate! if self.valid
      return false
    end

    return true
  end

  def invalidate!
    self.valid = false
    self.save
  end
end
