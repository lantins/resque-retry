require 'test_helper'

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

class MultipleFailureTest < MiniTest::Unit::TestCase

  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker

    @old_failure_backend = Resque::Failure.backend
    MockFailureBackend.errors = []
    Resque::Failure::MultipleWithRetrySuppression.classes = [ MockFailureBackend ]
    Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
  end

  def failure_key_for(klass)
    args = []
    key = 'failure-' + klass.redis_retry_key(args)
  end

  def test_failure_is_passed_on_when_job_class_not_found
    #skip 'commit 7113b0df to `resque` gem means the failure backend is never called. effects resque v1.20.0'
    new_job_class = Class.new(LimitThreeJob).tap { |klass| klass.send(:instance_variable_set, :@queue, LimitThreeJob.instance_variable_get(:@queue)) }
    Object.send(:const_set, 'LimitThreeJobTemp', new_job_class)
    Resque.enqueue(LimitThreeJobTemp)

    Object.send(:remove_const, 'LimitThreeJobTemp')
    perform_next_job(@worker)

    assert_equal 1, MockFailureBackend.errors.count, 'should have one error'
    assert_match /uninitialized constant.* LimitThreeJobTemp/, MockFailureBackend.errors.first
  end

  def test_last_failure_is_saved_in_redis_if_delay
    Resque.enqueue(LimitThreeJobDelay1Hour)
    perform_next_job(@worker)

    # I don't like this, but...
    key = failure_key_for(LimitThreeJobDelay1Hour)
    assert Resque.redis.exists(key)
  end

  def test_retry_key_splatting_args
    # were expecting this to be called three times:
    # - once when we queue the job to try again
    # - once before the job is executed.
    # - once by the failure backend.
    RetryDefaultsJob.expects(:redis_retry_key).with({'a' => 1, 'b' => 2}).times(3)

    Resque.enqueue(RetryDefaultsJob, {'a' => 1, 'b' => 2})
    perform_next_job(@worker)
  end

  def test_last_failure_removed_from_redis_after_error_limit
    3.times do
      Resque.enqueue(LimitThreeJobDelay1Hour)
      perform_next_job(@worker)
    end

    key = failure_key_for(LimitThreeJobDelay1Hour)
    assert Resque.redis.exists(key), 'key should still exist'

    Resque.enqueue(LimitThreeJobDelay1Hour)
    perform_next_job(@worker)
    assert !Resque.redis.exists(key), 'key should have been removed.'
  end

  def test_last_failure_has_double_delay_redis_expiry_if_delay
    Resque.enqueue(LimitThreeJobDelay1Hour)
    perform_next_job(@worker)

    # I don't like this, but...
    key = failure_key_for(LimitThreeJobDelay1Hour)
    assert_equal 7200, Resque.redis.ttl(key)
  end

  def test_last_failure_is_not_saved_in_redis_if_no_delay
    Resque.enqueue(LimitThreeJob)
    perform_next_job(@worker)

    # I don't like this, but...
    key = failure_key_for(LimitThreeJob)
    assert !Resque.redis.exists(key)
  end

  def test_errors_are_suppressed_up_to_retry_limit
    Resque.enqueue(LimitThreeJob)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, MockFailureBackend.errors.size
  end

  def test_errors_are_logged_after_retry_limit
    Resque.enqueue(LimitThreeJob)
    4.times do
      perform_next_job(@worker)
    end

    assert_equal 1, MockFailureBackend.errors.size
  end

  def test_jobs_without_retry_log_errors
    5.times do
      Resque.enqueue(NoRetryJob)
      perform_next_job(@worker)
    end

    assert_equal 5, MockFailureBackend.errors.size
  end

  def test_custom_retry_identifier_job
    Resque.enqueue(CustomRetryIdentifierFailingJob, 'qq', 2)
    4.times do
      perform_next_job(@worker)
    end
    assert_equal 1, MockFailureBackend.errors.size
  end

  def test_failure_with_retry_bumps_key_expire
    Resque.enqueue(FailFiveTimesWithExpiryJob, 'foo')
    retry_key = FailFiveTimesWithExpiryJob.redis_retry_key('foo')

    Resque.redis.expects(:expire).times(4).with(retry_key, 3600)
    4.times do
      perform_next_job(@worker)
    end
  end

  def teardown
    Resque::Failure.backend = @old_failure_backend
  end
end
