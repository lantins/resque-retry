require File.dirname(__FILE__) + '/test_helper'

class RetryCriteriaTest < Test::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_retry_criteria_check_should_retry
    Resque.enqueue(RetryModuleCustomRetryCriteriaCheckTrue)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_should_not_retry
    Resque.enqueue(RetryModuleCustomRetryCriteriaCheckFalse)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_hierarchy_should_not_retry
    Resque.enqueue(CustomRetryCriteriaCheckFirstLevel)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 1, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
  end

  def test_retry_criteria_check_hierarchy_should_retry
    Resque.enqueue(CustomRetryCriteriaCheckSecondLevel)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end
end