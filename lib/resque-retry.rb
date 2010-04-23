require 'resque'
begin; require 'resque_scheduler'; rescue LoadError; end

require 'resque/plugins/retry'
require 'resque/plugins/exponential_backoff'