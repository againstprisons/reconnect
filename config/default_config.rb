require 'securerandom'

class ReConnect::Application
  configure do
    set :session_secret, ENV.fetch('SESSION_SECRET') {SecureRandom.hex(32)}
  end
end
