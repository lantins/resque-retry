require 'test_helper'
require 'resque/failure/redis'
require 'digest/sha1'

class RetryTest < Minitest::Test
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
    Resque::Failure.backend = Resque::Failure::Redis
  end

  def test_resque_plugin_lint
    # will raise exception if were not a good plugin.
    assert Resque::Plugin.lint(Resque::Plugins::Retry)
  end

  def test_default_settings
    assert_equal 1, RetryDefaultSettingsJob.retry_limit, 'default retry limit'
    assert_equal 0, RetryDefaultSettingsJob.retry_attempt, 'default number of retry attempts'
    assert_nil RetryDefaultSettingsJob.fatal_exceptions, 'default fatal exceptions; nil = none'
    assert_nil RetryDefaultSettingsJob.retry_exceptions, 'default retry exceptions; nil = any'
    assert_equal 0, RetryDefaultSettingsJob.retry_delay, 'default seconds until retry'
  end

  def test_retry_once_by_default
    Resque.enqueue(RetryDefaultsJob)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end

  def test_module_retry_defaults
    Resque.enqueue(RetryModuleDefaultsJob)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end

  def test_job_args_are_maintained
    test_args = ['maiow', 'cat', [42, 84]]

    Resque.enqueue(RetryDefaultsJob, *test_args)
    perform_next_job(@worker)

    assert job = Resque.pop(:testing)
    assert_equal test_args, job['args']
  end

  def test_job_args_can_be_modified_by_overriding_retry_args
    Resque.enqueue(RetryWithModifiedArgsJob)
    RetryWithModifiedArgsJob.expects(:retry_args)
    perform_next_job(@worker)
  end

  def test_job_args_can_be_modified_by_overriding_retry_args_for_exception
    Resque.enqueue(RetryWithExceptionBasedArgsJob)
    RetryWithExceptionBasedArgsJob.expects(:retry_args_for_exception)
    perform_next_job(@worker)
  end

  def test_retry_never_give_up
    Resque.enqueue(NeverGiveUpJob)
    10.times do
      perform_next_job(@worker)
    end

    assert_equal 1, Resque.info[:pending], 'pending jobs'
    assert_equal 10, Resque.info[:failed], 'failed jobs'
    assert_equal 10, Resque.info[:processed], 'processed job'
  end

  def test_failure_before_perform_does_not_both_requeue_and_fail_the_job
    Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
    Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

    Resque.enqueue(FailsDuringConnectJob)

    perform_next_job_fail_on_reconnect(@worker)

    assert_equal 1, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.info[:failed], "should not be any failed jobs: #{Resque::Failure.all(0, 100)}"
    assert_equal 0, Resque.info[:pending], 'should not yet be any pending jobs'
    assert_equal 1, delayed_jobs.size, 'should be a delayed job'
  end

  def test_retry_never_retry
    Resque.enqueue(NeverRetryJob)
    10.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
  end

  def test_fail_five_times_then_succeed
    Resque.enqueue(FailFiveTimesJob)
    7.times do
      perform_next_job(@worker)
    end

    assert_equal 5, Resque.info[:failed], 'failed jobs'
    assert_equal 6, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.info[:pending], 'pending jobs'
  end

  def test_retry_delay_sleep
    assert_equal 0, Resque.info[:failed], 'failed jobs'
    Resque.enqueue(SleepDelay1SecondJob)
    before = Time.now
    2.times do
      perform_next_job(@worker)
    end
    actual_delay = Time.now - before

    assert actual_delay >= 1, "did not sleep long enough: #{actual_delay} seconds"
    assert actual_delay < 2, "slept too long: #{actual_delay} seconds"
    assert_equal 1, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.info[:pending], 'pending jobs'
  end

  def test_can_determine_if_exception_may_be_retried_with_defaults
    assert_equal true, RetryDefaultsJob.retry_exception?(StandardError), 'StandardError may retry'
    assert_equal true, RetryDefaultsJob.retry_exception?(CustomException), 'CustomException may retry'
    assert_equal true, RetryDefaultsJob.retry_exception?(HierarchyCustomException), 'HierarchyCustomException may retry'
  end

  def test_can_determine_if_exception_may_be_retried_with_custom_retry_exceptions
    assert_equal false, RetryCustomExceptionsJob.retry_exception?(StandardError), 'StandardError may not retry'
    assert_equal true, RetryCustomExceptionsJob.retry_exception?(CustomException), 'CustomException may retry'
    assert_equal true, RetryCustomExceptionsJob.retry_exception?(HierarchyCustomException), 'HierarchyCustomException may retry'
    assert_equal true, RetryCustomExceptionsJob.retry_exception?(RuntimeError.new.extend(CustomExceptionModule)), 'Extended with CustomExceptionModule may retry'
    assert_equal false, RetryCustomExceptionsJob.retry_exception?(AnotherCustomException), 'AnotherCustomException may not retry'
  end

  def test_retry_if_failed_and_exception_may_retry
    Resque.enqueue(RetryCustomExceptionsJob, CustomException)
    Resque.enqueue(RetryCustomExceptionsJob, HierarchyCustomException)
    4.times do
      perform_next_job(@worker)
    end

    assert_equal 4, Resque.info[:failed], 'failed jobs'
    assert_equal 4, Resque.info[:processed], 'processed job'
    assert_equal 2, Resque.info[:pending], 'pending jobs'
  end

  def test_retry_if_failed_and_exception_may_retry_because_of_included_module
    Resque.enqueue(RetryCustomExceptionsJob, 'tagged CustomException')
    4.times do
      perform_next_job(@worker)
    end

    assert_equal 4, Resque.info[:failed], 'failed jobs'
    assert_equal 4, Resque.info[:processed], 'processed job'
    assert_equal 1, Resque.info[:pending], 'pending jobs'
  end

  def test_do_not_retry_if_failed_and_exception_does_not_allow_retry
    Resque.enqueue(RetryCustomExceptionsJob, AnotherCustomException)
    Resque.enqueue(RetryCustomExceptionsJob, RuntimeError)
    4.times do
      perform_next_job(@worker)
    end

    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.info[:pending], 'pending jobs'
  end

  def test_dont_allow_both_retry_and_ignore_exceptions
    assert_raises Resque::Plugins::Retry::AmbiguousRetryStrategyException do
      AmbiguousRetryStrategyJob.extend(Resque::Plugins::Retry)
    end
  end

  def test_will_fail_immediately_if_exception_type_does_not_allow_retry
    Resque.enqueue(FailOnCustomExceptionJob)

    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
  end

  def test_will_retry_if_a_non_fatal_exception_is_raised
    Resque.enqueue(FailOnCustomExceptionButRaiseStandardErrorJob)

    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end

  def test_retry_failed_jobs_in_separate_queue
    Resque.enqueue(JobWithRetryQueue, 'arg1')

    perform_next_job(@worker)

    assert job_from_retry_queue = Resque.pop(:testing_retry_delegate)
    assert_equal ['arg1'], job_from_retry_queue['args']
    assert_nil Resque.redis.get(JobWithRetryQueue.redis_retry_key('arg1'))
  end

  def test_clean_retry_key_should_splat_args
    JobWithRetryQueue.expects(:clean_retry_key).once.with({"a" => 1, "b" => 2})

    Resque.enqueue(JobWithRetryQueue, {"a" => 1, "b" => 2})

    perform_next_job(@worker)
  end

  def test_delete_redis_key_when_job_is_successful
    Resque.enqueue(GoodJob, 'arg1')

    assert_nil Resque.redis.get(GoodJob.redis_retry_key('arg1'))
    perform_next_job(@worker)
    assert_nil Resque.redis.get(GoodJob.redis_retry_key('arg1'))
  end

  def test_delete_redis_key_after_final_failed_retry
    Resque.enqueue(FailFiveTimesJob, 'yarrrr')
    assert_nil Resque.redis.get(FailFiveTimesJob.redis_retry_key('yarrrr'))

    perform_next_job(@worker)
    assert_equal '0', Resque.redis.get(FailFiveTimesJob.redis_retry_key('yarrrr'))

    perform_next_job(@worker)
    assert_equal '1', Resque.redis.get(FailFiveTimesJob.redis_retry_key('yarrrr'))

    5.times do
      perform_next_job(@worker)
    end
    assert_nil Resque.redis.get(FailFiveTimesJob.redis_retry_key('yarrrr'))

    assert_equal 5, Resque.info[:failed], 'failed jobs'
    assert_equal 6, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.info[:pending], 'pending jobs'
  end

  def test_job_without_args_has_no_ending_colon_in_redis_key
    assert_equal 'resque-retry:GoodJob:' << Digest::SHA1.hexdigest('yarrrr'), GoodJob.redis_retry_key('yarrrr')
    assert_equal 'resque-retry:GoodJob:' << Digest::SHA1.hexdigest('foo'), GoodJob.redis_retry_key('foo')
    assert_equal 'resque-retry:GoodJob', GoodJob.redis_retry_key
  end

  def test_redis_retry_key_removes_whitespace_for_custom_retry_identifier
    klass = Class.new(GoodJob) do
      def self.retry_identifier(*args)
        args.join(' ')
      end
    end
    assert_equal 'resque-retry:abc', klass.redis_retry_key('a', 'b', 'c')
  end

  def test_retry_delay
    assert_equal 3, NormalRetryCountJob.retry_delay
    assert_equal 7, PerExceptionClassRetryCountJob.retry_delay(StandardError)
    assert_equal 7, PerExceptionClassRetryCountJob.retry_delay(CustomException)
    assert_equal 11, PerExceptionClassRetryCountJob.retry_delay(AnotherCustomException)
    assert_equal 13, PerExceptionClassRetryCountJob.retry_delay(HierarchyCustomException)

    assert_equal 7, PerExceptionClassRetryCountJob.instance_variable_get("@retry_exceptions")[CustomException]
  end

  def test_expire_key_set
    Resque.redis.expects(:expire).once.with(ExpiringJob.redis_retry_key('expiry_test'), 3600)
    Resque.enqueue(ExpiringJob, 'expiry_test')
    perform_next_job(@worker)
  end

  def test_expire_key_setting_on_the_fly
    retry_key = 'resque-retry:FailFiveTimesWithCustomExpiryJob'

    Resque.redis.expects(:expire).
      with(retry_key, 100).then.
      with(retry_key, 101).then.
      with(retry_key, 102).then.
      with(retry_key, 103).then.
      with(retry_key, 104)

    Resque.enqueue(FailFiveTimesWithCustomExpiryJob)
    5.times do
      perform_next_job(@worker)
    end
  end

  if Process.respond_to?(:fork) && Gem::Version.new(Resque::VERSION) >= Gem::Version.new('1.20.0')
    def test_retry_on_dirty_exit
      Resque.enqueue(RetryKilledJob)
      RetryKilledJob.expects(:clean_retry_key).once
      2.times do
        job = @worker.reserve
        child = fork do
          Resque.redis.client.reconnect
          job.perform
        end
        Process.waitpid(child)
        job.fail(Resque::DirtyExit.new)
      end

      assert_nil @worker.reserve
    end
  end
end
