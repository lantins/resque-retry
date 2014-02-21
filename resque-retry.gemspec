Gem::Specification.new do |s|
  s.name              = 'resque-retry'
  s.version           = '1.0.0'
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = 'A resque plugin; provides retry, delay and exponential backoff support for resque jobs.'
  s.homepage          = 'http://github.com/lantins/resque-retry'
  s.authors           = ['Luke Antins', 'Ryan Carver']
  s.email             = 'luke@lividpenguin.com'

  s.files             = %w(LICENSE Rakefile README.md HISTORY.md)
  s.files            += Dir.glob('{bin/*,test/*,lib/**/*}')
  s.require_paths     = ['lib']

  s.add_dependency('resque', '>= 1.25.1')
  s.add_dependency('resque-scheduler', '>= 1.9.9')
  s.add_development_dependency('rake')
  s.add_development_dependency('minitest', '~> 4.0')
  s.add_development_dependency('rack-test')
  s.add_development_dependency('yard')
  s.add_development_dependency('rdiscount') unless RUBY_PLATFORM == 'java'
  s.add_development_dependency('json')
  s.add_development_dependency('simplecov', '>= 0.3.0')
  s.add_development_dependency('mocha')
  # for 1.8 use a better timer please.
  s.add_development_dependency('SystemTimer') if Gem.ruby_version < Gem::Version.new('1.9')

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
