class SuccessfulJob
  @queue = :testing_successful

  # Perform that does nothing
  def self.perform(*args)
    # perform heavy lifting here.
  end
end

class FailingJob
  @queue = :testing_failure

  # Perform that raises an exception
  def self.perform(*args)
    raise 'this job is expected to fail!'
  end
end

class FailingWithRetryJob
  extend Resque::Plugins::Retry

  @queue = :testing_failure
  @retry_limit = 4
  @retry_delay = 3

  # Perform that raises an exception, but we will retry the job on failure
  def self.perform(*args)
    raise 'this job is expected to fail! but it will retry =)'
  end
end