require 'test_helper'

class RetryQueueTest < Minitest::Test
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_retry_delayed_failed_jobs_in_separate_queue
    Resque.enqueue(DelayedJobWithRetryQueue, 'arg1')
    Resque.expects(:enqueue_in_with_queue).with(:testing_retry_delegate, 1, JobRetryQueue, 'arg1')

    perform_next_job(@worker)
  end
end
