class GoodJob
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