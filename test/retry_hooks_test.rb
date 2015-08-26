require 'test_helper'

class RetryHooksTest < Minitest::Test
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_try_again_hooks_called
    # Fail, but don't not fatally
    Resque.enqueue(RetryHooksJob, false)
    order = sequence("hook_order")

    RetryHooksJob.expects(:on_try_again).once.in_sequence(order)
    RetryHooksJob.expects(:on_try_again_a).once.in_sequence(order)
    RetryHooksJob.expects(:on_try_again_b).once.in_sequence(order)

    RetryHooksJob.expects(:on_give_up).never
    RetryHooksJob.expects(:on_give_up_a).never
    RetryHooksJob.expects(:on_give_up_b).never

    perform_next_job(@worker)
  end

  def test_give_up_hooks_called
    # Fail fatally
    Resque.enqueue(RetryHooksJob, true)
    order = sequence("hook_order")

    RetryHooksJob.expects(:on_give_up).once.in_sequence(order)
    RetryHooksJob.expects(:on_give_up_a).once.in_sequence(order)
    RetryHooksJob.expects(:on_give_up_b).once.in_sequence(order)

    RetryHooksJob.expects(:on_try_again).never
    RetryHooksJob.expects(:on_try_again_a).never
    RetryHooksJob.expects(:on_try_again_b).never

    perform_next_job(@worker)
  end

  def test_try_again_hooks_called_then_give_up
    # Try once, retry, then try a second time and give up.
    Resque.enqueue(RetryHooksJob, false)
    order = sequence("hook_order")

    RetryHooksJob.expects(:on_try_again).once.in_sequence(order)
    RetryHooksJob.expects(:on_try_again_a).once.in_sequence(order)
    RetryHooksJob.expects(:on_try_again_b).once.in_sequence(order)

    RetryHooksJob.expects(:on_give_up).once.in_sequence(order)
    RetryHooksJob.expects(:on_give_up_a).once.in_sequence(order)
    RetryHooksJob.expects(:on_give_up_b).once.in_sequence(order)

    perform_next_job(@worker)  # Fail and retry
    perform_next_job(@worker)  # Fail and give up
  end
end
