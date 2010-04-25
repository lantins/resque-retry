require File.dirname(__FILE__) + '/test_helper'

class RetryTest < Test::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_resque_plugin_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Plugins::Retry)
    end
  end

  def test_retry_once_by_default
    Resque.enqueue(RetryDefaultsJob)
    3.times do
      perform_next_job(@worker)
    end

    assert_equal 0, Resque.info[:pending], 'pending jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 2, Resque.info[:processed], 'processed job'
  end

  def test_job_args_are_maintained
    test_args = ['maiow', 'cat', [42, 84]]

    Resque.enqueue(RetryDefaultsJob, *test_args)
    perform_next_job(@worker)

    assert job = Resque.pop(:testing)
    assert_equal test_args, job['args']
  end

  def test_job_args_may_be_modified
    Resque.enqueue(RetryWithModifiedArgsJob, 'foo', 'bar')
    perform_next_job(@worker)

    assert job = Resque.pop(:testing)
    assert_equal ['foobar', 'barbar'], job['args']
  end

  def test_retry_never_give_up
    Resque.enqueue(NeverGiveUpJob)
    10.times do
      perform_next_job(@worker)
    end

    assert_equal 1, Resque.info[:pending], 'pending jobs'
    assert_equal 10, Resque.info[:failed], 'failed jobs'
    assert_equal 10, Resque.info[:processed], 'processed job'
  end

  def test_fail_five_times_then_succeed
    Resque.enqueue(FailFiveTimesJob)
    7.times do
      perform_next_job(@worker)
    end

    assert_equal 5, Resque.info[:failed], 'failed jobs'
    assert_equal 6, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.info[:pending], 'pending jobs'
  end
end