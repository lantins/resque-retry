require File.expand_path(File.dirname(__FILE__) + '/test_helper')

class MultipleFailureTest < Test::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker

    @old_failure_backend = Resque::Failure.backend
    MockFailureBackend.errors = []
    Resque::Failure::MultipleWithRetrySuppression.classes = [MockFailureBackend]
    Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
  end

  def failure_key_for(klass)
    args = []
    key = "failure_" + klass.redis_retry_key(args)
  end

  def test_last_failure_is_saved_in_redis
    Resque.enqueue(LimitThreeJob)
    perform_next_job(@worker)

    # I don't like this, but...
    key = failure_key_for(LimitThreeJob)
    assert Resque.redis.exists(key)
  end

  def test_last_failure_removed_from_redis_after_error_limit
    Resque.enqueue(LimitThreeJob)
    3.times do
      perform_next_job(@worker)
    end

    key = failure_key_for(LimitThreeJob)
    assert Resque.redis.exists(key)

    perform_next_job(@worker)
    assert !Resque.redis.exists(key)
  end

  def test_on_success_failure_log_removed_from_redis
    SwitchToSuccessJob.successful_after = 1
    Resque.enqueue(SwitchToSuccessJob)
    perform_next_job(@worker)

    key = failure_key_for(SwitchToSuccessJob)
    assert Resque.redis.exists(key)

    perform_next_job(@worker)
    assert !Resque.redis.exists(key), 'key removed on success'
  ensure
    SwitchToSuccessJob.reset_defaults
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

  def teardown
    Resque::Failure.backend = @old_failure_backend
  end
end
