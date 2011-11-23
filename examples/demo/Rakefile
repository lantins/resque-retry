# Grab current directory.
dir = File.dirname(File.expand_path(__FILE__))
# Add current directory to load path (for Ruby 1.9.2).
$LOAD_PATH.unshift dir
# Make sure local resque-retry plugin is loaded
$LOAD_PATH.unshift dir + '/../../lib'


# Require resque & resque-retry.
require 'resque-retry'
require 'resque/failure/redis'

# Require Rakefile related resque things.
require 'resque/tasks'
require 'resque_scheduler/tasks'

# Enable resque-retry failure backend.
Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

# Require jobs & application code.
require 'jobs'

desc 'Start the demo using `rackup`'
task :start do 
  exec 'rackup config.ru'
end
