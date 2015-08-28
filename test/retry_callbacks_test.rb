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

    # xcxc add arguments too
    RetryCallbacksJob.expects(:on_try_again).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_a).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_try_again_b).once
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

    RetryCallbacksJob.expects(:on_give_up).once
      .with(instance_of(CustomException), true).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_a).once
      .with(instance_of(CustomException), true).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_b).once
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

    RetryCallbacksJob.expects(:on_give_up).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_a).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)
    RetryCallbacksJob.expects(:on_give_up_b).once
      .with(instance_of(AnotherCustomException), false).in_sequence(order)

    perform_next_job(@worker)  # Fail and retry
    perform_next_job(@worker)  # Fail and give up
  end
end
