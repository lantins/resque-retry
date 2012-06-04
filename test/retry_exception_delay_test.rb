require 'test_helper'

class RetryTest < MiniTest::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_retry_delay_per_exception_single_delay
    # store start time for later comparison with retry delay.
    start_time = Time.now.to_i

    # work the job a couple of times to build up some delayed jobs.
    3.times do
      Resque.enqueue(PerExceptionClassRetryCountJob)
      perform_next_job(@worker)
    end

    # double check job counts.
    assert_equal 3, Resque.info[:failed], 'failed jobs'
    assert_equal 3, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.info[:pending], 'zero pending jobs as their delayed'

    # now lets see if the delays are correct?
    delayed = Resque.delayed_queue_peek(0, 3)
    assert_in_delta (start_time + 7), delayed[0], 1.00, 'retry delay timestamp'
  end

  def test_retry_delay_per_exception_multiple_delay
    # store start time for later comparison with retry delay.
    start_time = Time.now.to_i

    # work the job a couple of times to build up some delayed jobs.
    3.times do
      Resque.enqueue(PerExceptionClassRetryCountArrayJob)
      perform_next_job(@worker)
    end

    # now lets see if the delays are correct?
    delayed = Resque.delayed_queue_peek(0, 3)
    assert_in_delta (start_time + 5),  delayed[0], 1.00, '1st retry delay timestamp'
    assert_in_delta (start_time + 10), delayed[1], 1.00, '2nd retry delay timestamp'
    assert_in_delta (start_time + 15), delayed[2], 1.00, '3rd retry delay timestamp'
  end

end
