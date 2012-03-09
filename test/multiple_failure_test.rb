require File.expand_path(File.dirname(__FILE__) + '/test_helper')

class MultipleFailureTest < MiniTest::Unit::TestCase
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

  def test_last_failure_is_saved_in_redis_if_delay
    Resque.enqueue(LimitThreeJobDelay1Hour)
    perform_next_job(@worker)

    # I don't like this, but...
    key = failure_key_for(LimitThreeJobDelay1Hour)
    assert Resque.redis.exists(key)
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

  def teardown
    Resque::Failure.backend = @old_failure_backend
  end
end
