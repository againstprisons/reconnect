class ReConnect::Models::Prison < Sequel::Model
  def delete!
    self.delete
  end
end
