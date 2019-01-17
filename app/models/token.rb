class ReConnect::Models::Token < Sequel::Model
  many_to_one :user

  def self.generate
    self.new(token: ReConnect::Crypto.generate_token, valid: true)
  end
end
