module ReConnect::Helpers
  def self.load_helpers
    require File.join(ReConnect.root, 'app', 'helpers', 'application_helpers')

    # And then load the rest
    Dir.glob(File.join(ReConnect.root, 'app', 'helpers', '*.rb')).each do |f|
      require f
    end
  end
end
