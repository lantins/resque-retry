require 'test_helper'

class IgnoreExceptionsTest < Minitest::Test
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_ignore_exceptions
    Resque.enqueue(IgnoreExceptionsJob)
    retry_key = IgnoreExceptionsJob.redis_retry_key

    IgnoreExceptionsJob.stubs(:perform).raises(AnotherCustomException)
    perform_next_job(@worker)
    assert_equal '0', Resque.redis.get(retry_key), 'retry counter'

    IgnoreExceptionsJob.stubs(:perform).raises(AnotherCustomException)
    perform_next_job(@worker)
    assert_equal '1', Resque.redis.get(retry_key), 'retry counter'

    IgnoreExceptionsJob.stubs(:perform).raises(CustomException)
    perform_next_job(@worker)
    assert_equal '1', Resque.redis.get(retry_key), 'retry counter'
  end
end
