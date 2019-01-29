require 'sidekiq'
require 'sidekiq-scheduler'

module ReConnect::Workers
  Dir.glob(File.join(ReConnect.root, 'app', 'workers', '*.rb')).each do |f|
    require f
  end
end
