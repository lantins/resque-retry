CustomException = Class.new(StandardError)
HierarchyCustomException = Class.new(CustomException)
AnotherCustomException = Class.new(StandardError)

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

module RetryModuleDefaultsJob
  extend Resque::Plugins::Retry
  @queue = :testing

  def self.perform(*args)
    raise
  end
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

# This job switches to successful after
# n +tries+.
class SwitchToSuccessJob < GoodJob
  @queue = :testing
  @max_retries = 3

  class << self
    attr_accessor :successful_after
    attr_accessor :tries

    def reset_defaults
      self.tries = 0
      self.successful_after = 2
    end
  end

  reset_defaults

  def self.perform(*args)
    if self.tries < self.successful_after
      self.tries += 1
      raise "error"
    end
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
