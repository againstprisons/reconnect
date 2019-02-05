class ReConnect::Models::Token < Sequel::Model
  many_to_one :user

  def self.generate
    self.new(token: ReConnect::Crypto.generate_token, valid: true, creation: Time.now, expiry: nil)
  end

  def check_expiry!
    return unless self.expiry

    if Time.now >= self.expiry
      self.invalidate!
      return true
    end

    return false
  end

  def invalidate!
    self.valid = false
    self.save
  end
end
