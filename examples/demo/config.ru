# Grab current directory.
dir = File.dirname(File.expand_path(__FILE__))
# Add current directory to load path (for Ruby 1.9.2).
$LOAD_PATH.unshift dir
# Make sure local resque-retry plugin is loaded
$LOAD_PATH.unshift dir + '/../../lib'

##############################################################################
###    REAL EXAMPLE STARTS HERE (_YOU_ WONT NEED THE SETUP CODE ABOVE)     ###
##############################################################################

# Require resque, resque-retry & web additions
require 'resque-retry'
require 'resque-retry/server'
require 'resque/failure/redis'

# Enable resque-retry failure backend.
Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

# Require jobs & application code.
require 'app'
require 'jobs'

# Password protect resque web application.
protected_resque = Rack::Builder.new do
  use Rack::Auth::Basic, 'Resque Web Interface' do |username, password|
    [username, password] == ['admin', 'password']
  end

  run Resque::Server.new
end

# Map application & resque web.
run Rack::URLMap.new({
  '/'            => ResqueRetryExampleApp.new,
  '/resque'      => protected_resque
})