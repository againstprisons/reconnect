class ReConnect::Models::IpBlock < Sequel::Model(:ip_blocks)
  def self.is_blocked?(ip_address)
    ip_address = ip_address&.strip&.downcase
    self.where(ip_address: ip_address).count.positive?
  end
end
