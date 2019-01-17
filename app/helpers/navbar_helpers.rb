module ReConnect::Helpers::NavbarHelpers
  def navbar_items
    return [] unless logged_in?
    items = []

    items << {
      :link => '/',
      :text => t(:'index/title'),
      :selected => current?('/'),
    }

    if has_role?("system:access")
      items << {
        :link => '/system',
        :text => t(:'system/title'),
        :selected => current_prefix?('/system'),
      }
    end

    # Account settings
    items << {
      :link => '/account',
      :text => t(:'account/title'),
      :selected => current_prefix?('/account'),
    }

    items
  end
end
