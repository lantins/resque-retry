class GoodJob
  @queue = :testing
  def self.perform(*args)
  end
end

class RetryDefaultsJob
  extend Resque::Plugins::Retry
  @queue = :testing

  def perform(*args)
    raise
  end
end

class NeverGiveUpJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 0
end

class FailFiveTimesJob < RetryDefaultsJob
  @queue = :testing
  @retry_limit = 6

  def perform(*args)
    raise if retry_attempt < 4
  end
end

class ExponentialBackoffJob < RetryDefaultsJob
  extend Resque::Plugins::ExponentialBackoff
  @queue = :testing
end