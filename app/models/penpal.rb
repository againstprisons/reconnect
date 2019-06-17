class ReConnect::Models::Penpal < Sequel::Model
  one_to_one :user

  def self.new_for_user(user)
    user = user.id if user.respond_to?(:id)
    self.new(:user_id => user, :is_incarcerated => false)
  end

  def get_name
    return self.user.get_name if self.user
    [self.decrypt(:first_name), self.decrypt(:last_name)]
  end

  def relationship_count
    ds_one = ReConnect::Models::PenpalRelationship.where(:penpal_one => self.id)
    ds_two = ReConnect::Models::PenpalRelationship.where(:penpal_two => self.id)

    ds_one.count + ds_two.count
  end

  def relationships
    ds_one = ReConnect::Models::PenpalRelationship.where(:penpal_one => self.id)
    ds_two = ReConnect::Models::PenpalRelationship.where(:penpal_two => self.id)

    [ds_one.all, ds_two.all].flatten.compact
  end

  def delete!
    # delete relationships
    self.relationships.map(&:delete!)

    # delete correspondence
    ReConnect::Models::Correspondence.where(:sending_penpal => self.id).delete
    ReConnect::Models::Correspondence.where(:receiving_penpal => self.id).delete

    # remove user association
    unless self.user_id.nil?
      u = self.user
      u&.penpal_id = nil
      u&.save

      self.user_id = nil
    end

    # clear filters
    ReConnect::Models::PenpalFilter.clear_filters_for(self)

    # bye!
    self.delete
  end
end

class ReConnect::Models::PenpalFilter < Sequel::Model
  many_to_one :penpal

  def self.clear_filters_for(penpal)
    penpal = penpal.id if penpal.respond_to?(:id)
    self.where(penpal_id: penpal).all.map(&:delete)
  end

  def self.create_filters_for(penpal)
    return [] unless [:get_name, :id].map{|x| penpal.respond_to?(x)}.all?

    filters = []

    # full name
    name = penpal.get_name&.join(" ")&.to_s&.strip&.downcase
    unless name.nil? || name.empty?
      name = name.encode(Encoding::UTF_8, :invalid => :replace, :undef => :replace, :replace => "")

      full_name = name.dup
      ReConnect.filter_strip_chars.each {|x| full_name.gsub!(x, "")}

      # filter on full name
      e = ReConnect::Crypto.index("Penpal", "name", full_name)
      filters << self.new(:penpal_id => penpal.id, :filter_label => "name", :filter_value => e)

      # filter on partial name
      name.split(" ").map{|x| x.split("-")}.flatten.each do |partial|
        ReConnect.filter_strip_chars.each {|x| partial.gsub!(x, "")}

        e = ReConnect::Crypto.index("Penpal", "name", partial)
        filters << self.new(:penpal_id => penpal.id, :filter_label => "name", :filter_value => e)
      end
    end

    # prisoner number
    prisoner_number = penpal.decrypt(:prisoner_number)&.to_s&.strip&.downcase
    unless prisoner_number.nil? || prisoner_number.empty? || prisoner_number == "(unknown)"
      ReConnect.filter_strip_chars.each {|x| prisoner_number.gsub!(x, "")}
      prisoner_number = prisoner_number.encode(Encoding::UTF_8, :invalid => :replace, :undef => :replace, :replace => "")

      e = ReConnect::Crypto.index("Penpal", "prisoner_number", prisoner_number)
      filters << self.new(:penpal_id => penpal.id, :filter_label => "prisoner_number", :filter_value => e)
    end

    # prison
    prison = penpal.decrypt(:prison_id)&.strip&.downcase.to_i
    prison = ReConnect::Models::Prison[prison]
    if prison
      e = ReConnect::Crypto.index("Penpal", "prison", prison.id.to_s)
      filters << self.new(:penpal_id => penpal.id, :filter_label => "prison", :filter_value => e)
    end

    filters.map(&:save)
    filters
  end

  def self.perform_filter(column, search)
    s = search.to_s.strip.downcase.encode(Encoding::UTF_8, :invalid => :replace, :undef => :replace, :replace => "")
    ReConnect.filter_strip_chars.each {|x| s.gsub!(x, "")}

    e = ReConnect::Crypto.index("Penpal", column.to_s.strip.downcase, s)
    self.where(:filter_label => column, :filter_value => e)
  end
end
