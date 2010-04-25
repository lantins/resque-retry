spec = Gem::Specification.new do |s|
  s.name              = 'resque-retry'
  s.version           = '0.0.1'
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = 'A resque plugin; provides retry, delay and exponential backoff support for resque jobs.'
  s.homepage          = 'http://github.com/lantins/resque-retry'
  s.authors           = ['Luke Antins']
  s.email             = 'luke@lividpenguin.com'
  s.has_rdoc          = false

  s.files             = %w(LICENSE Rakefile README.md)
  s.files            += Dir.glob('{test/*,lib/**/*}')
  s.require_paths     = ['lib']

  s.add_dependency('resque', '~> 1.8.0')
  s.add_development_dependency('turn')
  s.add_development_dependency('yard')

  s.description       = <<EOL
A resque plugin; provides retry, delay and exponential backoff support for
resque jobs.

Retry Example:

    require 'resque-retry'

    class DeliverWebHook
      extend Resque::Plugins::Retry

      def self.perform(url, hook_id, hmac_key)
        heavy_lifting
      end
    end
    
Exponential Backoff Example:

    class DeliverSMS
      extend Resque::Plugins::ExponentialBackoff

      def self.perform(mobile_number, message)
        heavy_lifting
      end
    end
EOL
end