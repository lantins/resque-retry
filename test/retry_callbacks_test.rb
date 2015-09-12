require 'test_helper'

class RetryCallbacksTest < Minitest::Test
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_try_again_callbacks_called
    # Fail, but not fatally
    Resque.enqueue(RetryCallbacksJob, false)
    order = sequence('callback_order')

    # Make sure that we're testing both blocks and symbols in our callbacks.
    refute_empty RetryCallbacksJob.try_again_callbacks.select { |x| x.is_a? Symbol }
    refute_empty RetryCallbacksJob.try_again_callbacks.select { |x| x.is_a? Proc }

    RetryCallbacksJob.expects(:on_try_again).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_a).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_b).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_c).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)

    RetryCallbacksJob.expects(:on_give_up).never
    RetryCallbacksJob.expects(:on_give_up_a).never
    RetryCallbacksJob.expects(:on_give_up_b).never

    perform_next_job(@worker)
  end

  def test_give_up_callbacks_called
    # Fail fatally
    Resque.enqueue(RetryCallbacksJob, true)
    order = sequence('callback_order')

    # Make sure that we're testing both blocks and symbols in our callbacks.
    refute_empty RetryCallbacksJob.give_up_callbacks.select { |x| x.is_a? Symbol }
    refute_empty RetryCallbacksJob.give_up_callbacks.select { |x| x.is_a? Proc }

    RetryCallbacksJob.expects(:on_give_up).once
      .with(instance_of(CustomException), true).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_a).once
      .with(instance_of(CustomException), true).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_b).once
      .with(instance_of(CustomException), true).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_c).once
      .with(instance_of(CustomException), true).in_sequence(order)

    RetryCallbacksJob.expects(:on_try_again).never
    RetryCallbacksJob.expects(:on_try_again_a).never
    RetryCallbacksJob.expects(:on_try_again_b).never

    perform_next_job(@worker)
  end

  def test_try_again_callbacks_called_then_give_up
    # Try once, retry, then try a second time and give up.
    Resque.enqueue(RetryCallbacksJob, false)
    order = sequence('callback_order')

    RetryCallbacksJob.expects(:on_try_again).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_a).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_b).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_c).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)

    RetryCallbacksJob.expects(:on_give_up).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_a).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_b).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_c).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)


    perform_next_job(@worker)  # Fail and retry
    perform_next_job(@worker)  # Fail and give up
  end

  # If an exception is raised in a try again callback, then it should fail and
  # not be retried.
  def test_try_again_callback_exception
    # Trigger a try again callback
    Resque.enqueue(RetryCallbacksJob, false)

    RetryCallbacksJob.expects(:on_try_again).once.raises(StandardError)
    RetryCallbacksJob.expects(:on_try_again_a).never
    RetryCallbacksJob.expects(:on_try_again_b).never
    RetryCallbacksJob.expects(:on_try_again_c).never

    perform_next_job(@worker)

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
  end

  # If an exception is raised in a give up callback, then it should fail and
  # not be retried.
  def test_give_up_callback_exception
    # Trigger a give up callback
    Resque.enqueue(RetryCallbacksJob, true)

    RetryCallbacksJob.expects(:on_give_up).once.raises(StandardError)
    RetryCallbacksJob.expects(:on_give_up_a).never
    RetryCallbacksJob.expects(:on_give_up_b).never
    RetryCallbacksJob.expects(:on_give_up_c).never

    perform_next_job(@worker)

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
  end
end
