require File.dirname(__FILE__) + '/test_helper'

class ExponentialBackoffTest < Test::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_resque_plugin_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Plugins::ExponentialBackoff)
    end
  end

  def test_default_backoff_strategy
    now = Time.now
    Resque.enqueue(ExponentialBackoffJob)

    perform_next_job @worker
    assert_equal 1, Resque.info[:processed], '1 processed job'
    assert_equal 1, Resque.info[:failed], 'first ever run, and it should of failed, but never retried'
    assert_equal 1, Resque.info[:pending], '1 pending job, because it never hits the scheduler'

    perform_next_job @worker
    assert_equal 2, Resque.info[:processed], '2nd run, but first retry'
    assert_equal 2, Resque.info[:failed], 'should of failed again, this is the first retry attempt'
    assert_equal 0, Resque.info[:pending], '0 pending jobs, it should be in the delayed queue'

    delayed = Resque.delayed_queue_peek(0, 1)
    assert_equal now.to_i + 60, delayed[0], '2nd delay' # the first had a zero delay.

    5.times do
      Resque.enqueue(ExponentialBackoffJob)
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 5)
    assert_equal now.to_i + 600, delayed[1], '3rd delay'
    assert_equal now.to_i + 3600, delayed[2], '4th delay'
    assert_equal now.to_i + 10_800, delayed[3], '5th delay'
    assert_equal now.to_i + 21_600, delayed[4], '6th delay'
  end

  def test_custom_backoff_strategy
    now = Time.now
    4.times do
      Resque.enqueue(CustomExponentialBackoffJob, 'http://lividpenguin.com', 1305, 'cd8079192d379dc612f17c660591a6cfb05f1dda')
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 3)
    assert_equal now.to_i + 10, delayed[0], '1st delay'
    assert_equal now.to_i + 20, delayed[1], '2nd delay'
    assert_equal now.to_i + 30, delayed[2], '3rd delay'
    assert_equal 2, Resque.delayed_timestamp_size(delayed[2]), '4th delay should share delay with 3rd'

    assert_equal 4, Resque.info[:processed], 'processed jobs'
    assert_equal 4, Resque.info[:failed], 'failed jobs'
    assert_equal 0, Resque.info[:pending], 'pending jobs'
  end
end
