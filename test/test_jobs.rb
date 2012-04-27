CustomException = Class.new(StandardError)
HierarchyCustomException = Class.new(CustomException)
AnotherCustomException = Class.new(StandardError)
TryLaterException = Class.new(StandardError)
TryIn3000Exception = Class.new(TryLaterException)

class NoRetryJob
  @queue = :testing

  def self.perform(*args)
    raise "error"
  end
end

class GoodJob
  extend Resque::Plugins::Retry
  @queue = :testing

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
    raise
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
  @queue = :testing_retry

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

  def self.args_for_retry(*args)
    args.each { |arg| arg << 'bar' }
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

class ExponentialBackoffJob < RetryDefaultsJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing
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
  @retry_exceptions = [CustomException, HierarchyCustomException]

  def self.perform(exception)
    case exception
    when 'CustomException' then raise CustomException
    when 'HierarchyCustomException' then raise HierarchyCustomException
    when 'AnotherCustomException' then raise AnotherCustomException
    else raise StandardError
    end
  end
end

class RetryAllButIrrecoverableJob < RetryDefaultsJob
  @queue = :testing

  @retry_limit = 5
  @ignore_exceptions = [TryIn3000Exception]

  def self.perform(exception)
    case exception
    when 'CustomException' then raise CustomException
    when 'TryLaterException' then raise TryLaterException
    when 'TryIn3000Exception' then raise TryIn3000Exception
    else raise StandardError
    end
  end
end

class AmbiguousExceptionsJob
  @queue = :testing

  @retry_exceptions = [CustomException, HierarchyCustomException]
  @ignore_exceptions = [TryIn3000Exception]
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
      %w(@retry_exceptions @retry_delay @retry_limit @auto_retry_limit).each do |variable|
        value = BaseJob.instance_variable_get(variable)
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
  @retry_exceptions = { RuntimeError => 7, Exception => 11, Timeout::Error => 13 }

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
