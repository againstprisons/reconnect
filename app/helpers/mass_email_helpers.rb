module ReConnect::Helpers::MassEmailHelpers
  include ReConnect::Helpers::LanguageHelpers

  def mass_email_groups(query)
    return nil if query.nil? || query&.empty?
    groups = query.split(",")

    if groups.include?('vl')
      return ReConnect.app_config['volunteer-group-ids']
    end

    groups.map(&:to_i).compact.uniq
  end
  
  def mass_email_display_groups(groups)
    return nil if groups.nil? || groups&.empty?

    if groups == ReConnect.app_config['volunteer-group-ids']
      return t(:'system/mass_email/all_volunteers')
    end

    groups.map(&:to_i).map do |gid|
      grp = ReConnect::Models::Group[gid]
      "#{grp.decrypt(:name).inspect} (#{gid})"
    end.join(", ")
  end
end