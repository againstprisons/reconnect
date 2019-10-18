module ReConnect::Helpers::SystemUserHelpers
  def user_view_data(u)
    data = {
      :id => u.id,
      :display_fields => [
        [t(:'user_id'), u.id],
      ],
    }

    # name
    data[:name_a] = name_a = u.get_name
    name = name_a.map{|x| x == "" ? nil : x}.compact.join(" ")
    name = "(unknown)" if name.nil? || name&.strip&.empty?
    data[:name] = name
    data[:display_fields] << [t(:'name/first'), name_a.first]
    data[:display_fields] << [t(:'name/last'), name_a.last]

    # pseudonym
    data[:pseudonym] = u.get_pseudonym
    data[:display_fields] << [t(:'pseudonym'), data[:pseudonym]]

    # email address
    data[:email_address] = u.email
    data[:display_fields] << [t(:'email_address'), u.email]

    # penpal id
    penpal = ReConnect::Models::Penpal[u.penpal_id]
    data[:penpal_id] = penpal&.id
    data[:display_fields] << [
      t(:'system/user/view/penpal_id'),
      penpal&.id.inspect
    ]

    # session count
    data[:sessions] = u.tokens
      .select{|x| x.use == "session" && x.valid}
      .count
    data[:display_fields] << [
      t(:'system/user/view/current_sessions'),
      data[:sessions]
    ]

    # role count
    data[:role_count] = u.user_roles.count
    data[:display_fields] << [
      t(:'system/user/view/role_count'),
      data[:role_count],
    ]

    # group count
    data[:group_count] = u.user_groups.count
    data[:display_fields] << [
      t(:'system/user/view/group_count'),
      data[:group_count]
    ]

    # group data
    data[:groups] = u.user_groups.map do |ug|
      group = ug.group

      {
        :objs => {
          :ug => ug,
          :group => group,
        },
        :ids => {
          :ug => ug.id,
          :group => group.id,
        },
        :name => group.decrypt(:name),
        :requires_2fa => group.requires_2fa,
      }
    end

    data
  end
end
