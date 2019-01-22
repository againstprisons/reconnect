class ReConnect::Models::PenpalRelationship < Sequel::Model
  def self.find_for_penpals(a, b)
    a = a.id if a.respond_to?(:id)
    b = b.id if b.respond_to?(:id)

    ab_ds = self.where(:penpal_one => a, :penpal_two => b)
    return ab_ds.first if ab_ds.count.positive?

    ba_ds = self.where(:penpal_one => b, :penpal_two => a)
    return ba_ds.first if ba_ds.count.positive?

    nil
  end
end
