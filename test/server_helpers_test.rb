require 'test_helper'
require 'resque'
require 'resque-retry/server'

class ServerHelpersTest < Minitest::Test
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker

    @helpers = Class.new.extend(ResqueRetry::Server::Helpers)
  end

  def test_retry_key_for_job
    Resque.enqueue(LimitThreeJobDelay1Hour)
    perform_next_job(@worker)

    timestamp = Resque.delayed_queue_peek(0, 1).first
    job = Resque.delayed_timestamp_peek(timestamp, 0, 1).first
    assert_equal '0', @helpers.retry_attempts_for_job(job), 'should have 0 retry attempt'
  end

  def test_retry_key_for_job_empty
    Resque.enqueue(DelayedJobNoRetryKey)
    perform_next_job(@worker)

    timestamp = Resque.delayed_queue_peek(0, 1).first
    job = Resque.delayed_timestamp_peek(timestamp, 0, 1).first
    retry_key = @helpers.retry_key_for_job(job)

    assert_nil retry_key, 'should be nil as the class does not respond to redis_retry_key'
    assert_nil @helpers.retry_attempts_for_job(job), 'should have nil retry attempts as the key does not exist'
    assert_nil @helpers.retry_failure_details(retry_key), 'should have nil failure details as the key does not exist'
  end
end
