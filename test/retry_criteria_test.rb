require File.dirname(__FILE__) + '/test_helper'

class RetryCriteriaTest < MiniTest::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_retry_criteria_check_should_retry
    Resque.enqueue(RetryModuleCustomRetryCriteriaCheck)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_hierarchy_should_not_retry
    Resque.enqueue(CustomRetryCriteriaCheckDontRetry)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_hierarchy_should_retry
    Resque.enqueue(CustomRetryCriteriaCheckDoRetry)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_multiple_never_retry
    Resque.enqueue(CustomRetryCriteriaCheckMultipleFailTwice, 'dont')
    6.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_multiple_do_retry
    Resque.enqueue(CustomRetryCriteriaCheckMultipleFailTwice, 'do')
    6.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 3, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_multiple_do_retry_again
    Resque.enqueue(CustomRetryCriteriaCheckMultipleFailTwice, 'do_again')
    6.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 3, Resque.info[:processed], 'processed job'
  end
end