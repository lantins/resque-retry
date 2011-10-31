spec = Gem::Specification.new do |s|
  s.name              = 'resque-retry'
  s.version           = '0.1.0'
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = 'A resque plugin; provides retry, delay and exponential backoff support for resque jobs.'
  s.homepage          = 'http://github.com/lantins/resque-retry'
  s.authors           = ['Luke Antins', 'Ryan Carver']
  s.email             = 'luke@lividpenguin.com'
  s.has_rdoc          = false

  s.files             = %w(LICENSE Rakefile README.md HISTORY.md)
  s.files            += Dir.glob('{test/*,lib/**/*}')
  s.require_paths     = ['lib']

  s.add_dependency('resque', '>= 1.8.0')
  s.add_dependency('resque-scheduler', '>= 1.8.0')
  s.add_development_dependency('test-unit')
  s.add_development_dependency('turn')
  s.add_development_dependency('yard')
  s.add_development_dependency('simplecov', '>= 0.3.0')
  s.add_development_dependency('mocha')

  s.description       = <<-EOL
  resque-retry provides retry, delay and exponential backoff support for
  resque jobs.

  Features:

  * Redis backed retry count/limit.
  * Retry on all or specific exceptions.
  * Exponential backoff (varying the delay between retrys).
  * Multiple failure backend with retry suppression & resque-web tab.
  * Small & Extendable - plenty of places to override retry logic/settings.
  EOL
end
