module ReConnect::Helpers::SystemConfigurationHelpers
  def config_keyvalue_entries
    ReConnect::Models::Config.all.map do |e|
      value = e.value.to_s
      truncated = value
      if value.length > 50
        truncated = value[0..49] + t(:'system/configuration/key_value/entry_truncated', :length => value.length)
      end

      [
        e.key,
        {
          :type => e.type,
          :value => value,
          :value_truncated => truncated,
          :deprecated => ReConnect::APP_CONFIG_DEPRECATED_ENTRIES[e.key],
          :edit_link => "/system/configuration/keys/#{e.key}",
        }
      ]
    end.to_h
  end

  def config_mail_entries
    keys = [
      "email-from",
      "email-smtp-host",
      "email-subject-prefix",
    ]

    keys.map do |key|
      e = ReConnect::Models::Config.where(:key => key).first
      next nil unless e

      [
        e.key,
        {
          :type => e.type,
          :value => e.value,
        }
      ]
    end.compact.to_h
  end
end
