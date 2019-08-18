class ReConnect::Models::PenpalDuplicate < Sequel::Model(:penpal_duplicates)
  def self.create_index(prn)
    ReConnect::Crypto.index("PenpalDuplicate", "prisoner_number", prn.to_s)
  end
end
