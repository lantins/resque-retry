CustomException = Class.new(StandardError)
HierarchyCustomException = Class.new(CustomException)
AnotherCustomException = Class.new(StandardError)

class GoodJob
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

class RetryWithModifiedArgsJob < RetryDefaultsJob
  @queue = :testing

  def self.args_for_retry(*args)
    args.each { |arg| arg << 'bar' }
  end
end

class NeverGiveUpJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 0
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