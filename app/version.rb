require 'memoist'

module ReConnect
  VERSION = "1.1.0"

  class << self
    extend Memoist

    def version
      gitrev = `sh -c 'command -v git >/dev/null && git describe --always --tags --abbrev --dirty'`.strip
      if gitrev != ""
        "v#{VERSION} rev #{gitrev}"
      else
        "v#{VERSION}"
      end
    end

    memoize :version
  end
end
