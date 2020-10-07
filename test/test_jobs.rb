CustomException = Class.new(StandardError)
CustomExceptionModule = Module.new
HierarchyCustomException = Class.new(CustomException)
AnotherCustomException = Class.new(StandardError)

class NoRetryJob
  @queue = :testing

  def self.perform(*args)
    raise 'error'
  end
end

class GoodJob
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.perform(*args)
  end
end

class ExpiringJob
  extend Resque::Plugins::Retry
  @queue = :testing
  @expire_retry_key_after = 60 * 60

  def self.perform(*args)
  end
end

class ExpiringJobWithRetryExceptions
  extend Resque::Plugins::Retry

  @queue = :testing
  @expire_retry_key_after = 10
  @retry_exceptions = { StandardError => 7 }

  def self.perform(*args)
  end
end

class RetryDefaultSettingsJob
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.perform(*args)
  end
end

class RetryDefaultsJob
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.perform(*args)
    raise 'error'
  end
end

class SleepDelay1SecondJob < RetryDefaultsJob
  @queue = :testing
  @sleep_after_requeue = 1

  def self.perform(*args)
    raise if retry_attempt == 0
  end
end

class JobRetryQueue
  extend Resque::Plugins::Retry
  @queue = :testing_retry_delegate

  def self.perform(*args)
  end
end

class JobWithRetryQueue
  extend Resque::Plugins::Retry
  @queue = :testing
  @retry_job_delegate = JobRetryQueue

  def self.perform(*args)
    raise
  end
end

class JobWithDynamicRetryQueue
  extend Resque::Plugins::Retry
  @queue = :testing
  @retry_delay = 1

  def self.retry_queue(exception, *args)
    args.first
  end

  def self.perform(*args)
    raise
  end
end

class DynamicDelayedJobOnExceptionAndArgs
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.retry_delay(exception, *args)
    args.first.to_i
  end

  def self.perform(*args)
    raise
  end
end

class DynamicDelayedJobOnException
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.retry_delay(exception)
    if exception == SocketError
      4
    else
      1
    end
  end

  def self.perform(*args)
    raise SocketError
  end
end

class DelayedJobWithRetryQueue
  extend Resque::Plugins::Retry
  @queue = :testing
  @retry_delay = 1
  @retry_job_delegate = JobRetryQueue

  def self.perform(*args)
    raise
  end
end

class InheritTestJob < RetryDefaultsJob
end

class InheritTestWithExtraJob < InheritTestJob
  retry_criteria_check do |exception, *args|
    false
  end
end

class InheritTestWithMoreExtraJob < InheritTestWithExtraJob
  retry_criteria_check do |exception, *args|
    false
  end

  retry_criteria_check do |exception, *args|
    false
  end
end

class RetryWithModifiedArgsJob < RetryDefaultsJob
  @queue = :testing

  def self.retry_args(*args)
    # NOTE: implementation is irrelevant we only care that it's invoked
  end
end

class RetryWithExceptionBasedArgsJob < RetryDefaultsJob
  @queue = :testing

  def self.retry_args_for_exception(exception, *args)
    # NOTE: implementation is irrelevant we only care that it's invoked
  end
end

class NeverGiveUpJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = -1
end

class NeverRetryJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 0
end

class LimitThreeJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 3

  def self.perform(*args)
    raise ArgumentError, "custom message"
  end
end

class LimitThreeJobDelay1Hour < LimitThreeJob
  @queue = :testing
  @retry_limit = 3
  @retry_delay = 3600
end

class FailFiveTimesJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 6

  def self.perform(*args)
    raise if retry_attempt <= 4
  end
end

class FailFiveTimesWithExpiryJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 6
  @expire_retry_key_after = 60 * 60

  def self.perform(*args)
    raise if retry_attempt <= 4
  end
end

class FailFiveTimesWithCustomExpiryJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 6

  def self.expire_retry_key_after
    retry_attempt + 100
  end

  def self.perform(*args)
    raise if retry_attempt <= 4
  end
end

class ExponentialBackoffJob < RetryDefaultsJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing
end

class ExponentialBackoffWithRetryDelayMultiplicandMinJob < RetryDefaultsJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing
  @retry_delay_multiplicand_min = 0.5
end

class ExponentialBackoffWithRetryDelayMultiplicandMaxJob < RetryDefaultsJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing
  @retry_delay_multiplicand_max = 3.0
end

class ExponentialBackoffWithRetryDelayMultiplicandMinAndMaxJob < RetryDefaultsJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing
  @retry_delay_multiplicand_min = 0.5
  @retry_delay_multiplicand_max = 3.0
end

class ExponentialBackoffWithExpiryJob < RetryDefaultsJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing
  @expire_retry_key_after = 60 * 60
end

class InvalidRetryDelayMaxConfigurationJob
  @queue = :testing
  @retry_delay_multiplicand_max = 0.9
end

class InvalidRetryDelayMinConfigurationJob
  @queue = :testing
  @retry_delay_multiplicand_min = 1.1
end

class InvalidRetryDelayMinAndMaxConfigurationJob
  @queue = :testing
  @retry_delay_multiplicand_min = 3.0
  @retry_delay_multiplicand_max = 0.5
end

class CustomExponentialBackoffJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing

  @retry_limit = 4
  @backoff_strategy = [10, 20, 30]

  def self.perform(url, hook_id, hmac_key)
    raise
  end
end

class RetryCustomExceptionsJob < RetryDefaultsJob
  @queue = :testing

  @retry_limit = 5
  @retry_exceptions = [CustomException, CustomExceptionModule, HierarchyCustomException]

  def self.perform(exception)
    case exception
    when 'CustomException' then raise CustomException
    when 'HierarchyCustomException' then raise HierarchyCustomException
    when 'tagged CustomException' then raise AnotherCustomException.new.extend(CustomExceptionModule)
    when 'AnotherCustomException' then raise AnotherCustomException
    else raise StandardError
    end
  end
end

class AmbiguousRetryStrategyJob
  @queue = :testing

  @fatal_exceptions = [CustomException]
  @retry_exceptions = [AnotherCustomException]
end

class FailOnCustomExceptionJob
  extend Resque::Plugins::Retry
  @queue = :testing

  @fatal_exceptions = [CustomException]

  def self.perform(*args)
    raise CustomException
  end
end

class FailOnCustomExceptionButRaiseStandardErrorJob
  extend Resque::Plugins::Retry
  @queue = :testing

  @fatal_exceptions = [CustomException]

  def self.perform(*args)
    raise StandardError
  end
end

module RetryModuleDefaultsJob
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.perform(*args)
    raise
  end
end

class AsyncJob
  extend Resque::Plugins::Retry

  class << self
    def perform(*opts)
      process
    end

    def process
      raise "Shouldn't be called"
    end
  end
end

class BaseJob < AsyncJob
  @retry_limit = -1
  @auto_retry_limit = 5
  @retry_exceptions = []

  retry_criteria_check do |exception, *args|
    keep_trying?
  end

  class << self
    def keep_trying?
      retry_attempt < @auto_retry_limit
    end

    def inherited(subclass)
      super
      %i[
        @auto_retry_limit
        @retry_delay
        @retry_exceptions
        @retry_limit
      ].each do |variable|
        value = nil
        value = BaseJob.instance_variable_get(variable) \
          if BaseJob.instance_variable_defined?(variable)
        value = value.dup rescue value
        subclass.instance_variable_set(variable, value)
      end
    end

    def process
      raise "Got called #{Time.now}"
    end
  end
end

class InheritedRetryJob < BaseJob
  @queue = :testing
end

class InheritedJob < BaseJob
  @queue = :testing
  @retry_job_delegate = InheritedRetryJob
end

module RetryModuleCustomRetryCriteriaCheck
  extend Resque::Plugins::Retry
  @queue = :testing

  # make sure the retry exceptions check will return false.
  @retry_exceptions = [CustomException]

  retry_criteria_check do |exception, *args|
    true
  end

  def self.perform(*args)
    raise
  end
end

class CustomRetryCriteriaCheckDontRetry < RetryDefaultsJob
  @queue = :testing

  # make sure the retry exceptions check will return false.
  @retry_exceptions = [CustomException]

  retry_criteria_check do |exception, *args|
    false
  end
end

class CustomRetryCriteriaCheckDoRetry < CustomRetryCriteriaCheckDontRetry
  @queue = :testing

  # make sure the retry exceptions check will return false.
  @retry_exceptions = [CustomException]

  retry_criteria_check do |exception, *args|
    true
  end
end

# A job using multiple custom retry criteria checks.
# It always fails 2 times.
class CustomRetryCriteriaCheckMultipleFailTwice
  extend Resque::Plugins::Retry
  @retry_limit = 6
  @queue = :testing

  # make sure we dont retry due to default exception behaviour.
  @retry_exceptions = []

  retry_criteria_check do |exception, *args|
    exception.message == 'dont' ? false : true
  end

  retry_criteria_check do |exception, *args|
    exception.message == 'do' ? true : false
  end

  retry_criteria_check do |exception, *args|
    exception.message == 'do_again' ? true : false
  end

  def self.perform(msg)
    if retry_attempt < 2 # always fail twice please.
      raise StandardError, msg
    end
  end
end

# A job that defines a custom retry criteria check via a symbol, for a method
# that is already defined.
class CustomRetryCriteriaWithSymbol
  extend Resque::Plugins::Retry
  @queue = :testing

  # make sure the retry exceptions check will return false.
  @retry_exceptions = [CustomException]

  retry_criteria_check :yes

  def self.yes(ex, *args); true; end

  def self.perform(*args)
    raise
  end
end

# A job to test whether self.inherited is respected
# when added by other modules.
class InheritOrderingJobExtendFirst
  extend Resque::Plugins::Retry

  retry_criteria_check do |exception, *args|
    false
  end

  class << self
    attr_accessor :test_value
  end

  def self.inherited(subclass)
    super(subclass)
    subclass.test_value = 'test'
  end
end

class InheritOrderingJobExtendLast
  class << self
    attr_accessor :test_value
  end

  def self.inherited(subclass)
    super(subclass)
    subclass.test_value = 'test'
  end

  extend Resque::Plugins::Retry

  retry_criteria_check do |exception, *args|
    false
  end
end


class InheritOrderingJobExtendFirstSubclass < InheritOrderingJobExtendFirst; end
class InheritOrderingJobExtendLastSubclass < InheritOrderingJobExtendLast; end

class CustomRetryIdentifierFailingJob
  extend Resque::Plugins::Retry

  @queue = :testing
  @retry_limit = 2
  @retry_delay = 0

  def self.retry_identifier(*args)
    args.first.to_s
  end

  def self.perform(*args)
    raise 'failed'
  end
end

class NoRetryDelayJob
  extend Resque::Plugins::Retry

  @queue = :testing
  @retry_exceptions = {}
end

class NormalRetryCountJob
  extend Resque::Plugins::Retry

  @queue = :testing
  @retry_delay = 3
  @retry_exceptions = [RuntimeError, Exception, Timeout::Error]
end

class PerExceptionClassRetryCountJob
  extend Resque::Plugins::Retry

  @queue = :testing
  @retry_limit = 3
  @retry_exceptions = { StandardError => 7, AnotherCustomException => 11, HierarchyCustomException => 13 }

  def self.perform
    raise RuntimeError, 'I always fail with a RuntimeError'
  end
end

class PerExceptionClassRetryCountArrayJob
  extend Resque::Plugins::Retry

  @queue = :testing
  @retry_limit = 3
  @retry_exceptions = { Exception => 11, RuntimeError => [5, 10, 15],  Timeout::Error => [2, 4, 6, 8, 10] }

  def self.perform
    raise RuntimeError, 'I always fail with a RuntimeError'
  end
end

class PerExceptionClassRetryCountArrayNoRetryLimitSpecifiedJob
  extend Resque::Plugins::Retry

  @queue = :testing
  @retry_exceptions = { Exception => 11, RuntimeError => [5, 10, 15],  Timeout::Error => [2, 4, 6, 8, 10] }

  def self.perform
    raise RuntimeError, 'I always fail with a RuntimeError'
  end
end

# We can't design a job to fail during connect, see perform_next_job_fail_on_reconnect
class FailsDuringConnectJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 3
  @retry_delay = 10
end

class RetryKilledJob
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.perform(*args)
    Process.kill("KILL", Process.pid)
  end
end

class RetryCallbacksJob
  extend Resque::Plugins::Retry
  @queue = :testing

  @fatal_exceptions = [CustomException]
  @retry_exceptions = [AnotherCustomException]
  @retry_limit = 1

  def self.perform(is_fatal)
    if is_fatal
      raise CustomException, "RetryCallbacksJob failed fatally"
    else
      raise AnotherCustomException, "RetryCallbacksJob failed"
    end
  end

  def self.on_try_again(ex, *args); end
  def self.on_try_again_a(ex, *args); end
  def self.on_try_again_b(ex, *args); end
  def self.on_try_again_c(ex, *args); end

  def self.on_give_up(ex, *args); end
  def self.on_give_up_a(ex, *args); end
  def self.on_give_up_b(ex, *args); end
  def self.on_give_up_c(ex, *args); end

  @try_again_callbacks = [
    lambda { |*args| self.on_try_again(*args) },
    :on_try_again_a
  ]

  try_again_callback do |*args|
    on_try_again_b(*args)
  end

  try_again_callback :on_try_again_c

  @give_up_callbacks = [
    lambda { |*args| self.on_give_up(*args) },
    :on_give_up_a
  ]

  give_up_callback do |*args|
    on_give_up_b(*args)
  end

  give_up_callback :on_give_up_c
end

class IgnoreExceptionsJob
  extend Resque::Plugins::Retry
  @queue = :testing
  @ignore_exceptions = [CustomException]
  @retry_exceptions = [CustomException, AnotherCustomException]
  @retry_limit = 3

  def self.perform
    "Hello, World!"
  end
end
