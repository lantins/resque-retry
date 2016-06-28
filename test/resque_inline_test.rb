require 'test_helper'

class IgnoreExceptionsTest < Minitest::Test
  def setup
    Resque.stubs(:redis)
    Resque.inline = true
  end

  def teardown
    Resque.inline = false
    Resque.unstub(:redis)
  end

  def test_ignore_exceptions
    GoodJob.stubs(:perform).raises(CustomException)
    assert_raises CustomException do
      Resque.enqueue(GoodJob)
    end
    GoodJob.unstub(:perform)
  end
end
