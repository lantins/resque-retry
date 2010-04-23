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

  def test_backoff_strategy
    now = Time.now
    Resque.enqueue(ExponentialBackoffJob)
    2.times do
      perform_next_job @worker
    end

    assert_equal 2, Resque.info[:processed], 'processed jobs'
    assert_equal 2, Resque.info[:failed], 'failed jobs'
    assert_equal 0, Resque.info[:pending], 'pending jobs'

    delayed = Resque.delayed_queue_peek(0, 1)
    assert_equal now.to_i + 60, delayed[0], '1st delay'

    5.times do
      Resque.enqueue(ExponentialBackoffJob)
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 5)
    assert_equal now.to_i + 600, delayed[1], '2nd delay'
    assert_equal now.to_i + 3600, delayed[2], '3rd delay'
    assert_equal now.to_i + 10_800, delayed[3], '4th delay'
    assert_equal now.to_i + 21_600, delayed[4], '5th delay'
  end
end