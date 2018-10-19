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

  def test_retry_delayed_failed_jobs_in_dynamic_queue
    queue_name = "dynamic_queue_#{Time.now.to_i}"

    Resque.enqueue(JobWithDynamicRetryQueue, queue_name)
    Resque.expects(:enqueue_in_with_queue).with(queue_name, 1, JobWithDynamicRetryQueue, queue_name)

    perform_next_job(@worker)
  end
end
