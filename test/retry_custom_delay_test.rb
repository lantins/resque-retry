require 'test_helper'

class RetryCustomDelayTest < Minitest::Test
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_delay_with_exception
    Resque.enqueue(DynamicDelayedJobOnException, 'arg1')
    Resque.expects(:enqueue_in_with_queue).with(:testing, 4, DynamicDelayedJobOnException, 'arg1')

    perform_next_job(@worker)
  end

  def test_delay_with_exception_and_args
    Resque.enqueue(DynamicDelayedJobOnExceptionAndArgs, '3')
    Resque.expects(:enqueue_in_with_queue).with(:testing, 3, DynamicDelayedJobOnExceptionAndArgs, '3')

    perform_next_job(@worker)
  end
end
