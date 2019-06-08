module ReConnect::Helpers::SystemConfigurationFilterHelpers
  def filter_get_db_words
    dbentry = ReConnect::Models::Config.where(:key => 'filter-words').first
    return {:err => :noentry, :val => []} unless dbentry

    parsed = nil
    begin
      parsed = JSON.parse(dbentry.value)
    rescue => e
      return {:err => :parse, :val => []}
    end

    if parsed.nil?
      return {:err => :parsed_nil, :val => []}
    end

    {:err => nil, :val => parsed}
  end
end

