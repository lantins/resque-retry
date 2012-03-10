dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
$TESTING = true

require 'rubygems'
require 'minitest/unit'
require 'minitest/pride'
require 'rack/test'
require 'mocha'
require 'simplecov'

SimpleCov.start do
  add_filter "/test/"
end unless RUBY_PLATFORM == 'java'

require 'resque-retry'
require dir + '/test_jobs'

# make sure we can run redis
if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end


# start our own redis when the tests start,
# kill it when they end
at_exit do
  next if $!

  exit_code = MiniTest::Unit.new.run(ARGV)

  pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server..."
  `rm -f #{dir}/dump.rdb`
  Process.kill("KILL", pid.to_i)
  exit exit_code
end

puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis-test.conf`
Resque.redis = '127.0.0.1:9736'

# Mock failure backend for testing MultipleWithRetrySuppression
class MockFailureBackend < Resque::Failure::Base
  class << self
    attr_accessor :errors
  end

  def save
    self.class.errors << exception.to_s
  end

  self.errors = []
end

# Test helpers
class MiniTest::Unit::TestCase
  def perform_next_job(worker, &block)
    return unless job = @worker.reserve
    @worker.perform(job, &block)
    @worker.done_working
  end

  def clean_perform_job(klass, *args)
    Resque.redis.flushall
    Resque.enqueue(klass, *args)

    worker = Resque::Worker.new(:testing)
    return false unless job = worker.reserve
    worker.perform(job)
    worker.done_working
  end
end
