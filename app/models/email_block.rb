class ReConnect::Models::EmailBlock < Sequel::Model(:email_blocks)
  def self.is_blocked?(email)
    email = email&.strip&.downcase
    return false if email.nil?

    domain = email.split('@', 2).last
    return true if self.where(email: email, is_domain: false).count.positive?
    return true if self.where(email: domain, is_domain: true).count.positive?
    false
  end
end
