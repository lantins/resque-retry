dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
$TESTING = true

# Run code coverage in MRI 1.9 only.
if RUBY_VERSION >= '1.9' && RUBY_ENGINE == 'ruby'
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
end

require 'rubygems'
require 'timeout'
require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require 'mocha/setup'

require 'resque-retry'
require dir + '/test_jobs'

if ENV['CI'] != 'true'
  # make sure we can run redis-server
  if !system('which redis-server')
    puts '', "** `redis-server` was not found in your PATH"
    abort ''
  end

  # make sure we can shutdown the server using cli.
  if !system('which redis-cli')
    puts '', "** `redis-cli` was not found in your PATH"
    abort ''
  end

  # This code is run after all the tests have finished running to ensure that the
  # Redis server is shutdowa
  Minitest.after_run { `redis-cli -p 9736 shutdown nosave` }

  puts "Starting redis for testing at localhost:9736..."
  `redis-server #{dir}/redis-test.conf`
  Resque.redis = '127.0.0.1:9736'
else
  Resque.redis = '127.0.0.1:6379'
end

# Test helpers
class Minitest::Test
  def perform_next_job(worker, &block)
    return unless job = worker.reserve
    worker.perform(job, &block)
    worker.done_working
  end

  def perform_next_job_fail_on_reconnect(worker,&block)
    raise "No work for #{worker}" unless job = worker.reserve
    worker.working_on job

    # Similar to resque's Worker.work and Worker.process methods
    begin
      raise 'error from perform_next_job_fail_on_reconnect'
      worker.perform(job, &block)
    rescue Exception => exception
      worker.report_failed_job(job, exception)
    ensure
      worker.done_working
    end
  end

  def delayed_jobs
    # The double-checks here are so that we won't blow up if the config stops using redis-namespace
    timestamps = Resque.redis.zrange("resque:delayed_queue_schedule", 0, -1) +
                 Resque.redis.zrange("delayed_queue_schedule", 0, -1)

    delayed_jobs_as_json = timestamps.map do |timestamp|
      Resque.redis.lrange("resque:delayed:#{timestamp}", 0, -1) +
      Resque.redis.lrange("delayed:#{timestamp}", 0, -1)
    end.flatten

    delayed_jobs_as_json.map { |json| JSON.parse(json) }
  end

  def clean_perform_job(klass, *args)
    Resque.redis.flushall
    Resque.enqueue(klass, *args)
    worker = Resque::Worker.new(:testing)
    perform_next_job(worker)
  end
end
