require 'base32'

class ReConnect::Models::Token < Sequel::Model
  FULL_TOKEN_LENGTH = (ReConnect::Crypto::TOKEN_LENGTH * 2)
  SHORT_TOKEN_LENGTH = 16

  many_to_one :user  

  def self.generate
    token = ReConnect::Crypto.generate_token
    self.new(token: token, valid: true, creation: Time.now, expiry: nil)
  end

  def self.generate_short
    token = ReConnect::Utils.hex_to_bin(ReConnect::Crypto.generate_token())
    token = Base32.encode(token).downcase[0..(SHORT_TOKEN_LENGTH - 1)]
    self.new(token: token, valid: true, creation: Time.now, expiry: nil)
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
