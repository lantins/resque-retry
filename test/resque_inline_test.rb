require 'test_helper'

class ResqueInlineTest < Minitest::Test
  def setup
    Resque.inline = true
    Resque.expects(:redis).never
  end

  def teardown
    Resque.inline = false
  end

  def test_runs_inline
    GoodJob.expects :perform
    Resque.enqueue(GoodJob)
  end

  def test_fails_inline
    assert_raises CustomException do
      Resque.enqueue(RetryCustomExceptionsJob, 'CustomException')
    end
  end
end
