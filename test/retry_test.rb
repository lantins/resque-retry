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

  def test_good_job
    clean_perform_job(GoodJob, 1234, { :cats => :maiow }, [true, false, false])

    assert_equal 0, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.delayed_queue_schedule_size
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

  def test_fail_five_times_then_work
    Resque.enqueue(FailFiveTimesJob)
    7.times do
      perform_next_job(@worker)
    end

    assert_equal 7, Resque.info[:failed], 'failed jobs'
    assert_equal 7, Resque.info[:processed], 'processed job'
  end
end