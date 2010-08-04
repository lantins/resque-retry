require File.dirname(__FILE__) + '/test_helper'

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
