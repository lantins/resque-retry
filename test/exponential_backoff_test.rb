require 'test_helper'

class ExponentialBackoffTest < MiniTest::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_resque_plugin_lint
    # will raise exception if were not a good plugin.
    assert Resque::Plugin.lint(Resque::Plugins::ExponentialBackoff)
  end

  def test_default_backoff_strategy
    start_time = Time.now.to_i
    Resque.enqueue(ExponentialBackoffJob)

    perform_next_job @worker
    assert_equal 1, Resque.info[:processed],  '1 processed job'
    assert_equal 1, Resque.info[:failed],     'first ever run, and it should have failed, but never retried'
    assert_equal 1, Resque.info[:pending],    '1 pending job, because it never hits the scheduler'

    perform_next_job @worker
    assert_equal 2, Resque.info[:processed],  '2nd run, but first retry'
    assert_equal 2, Resque.info[:failed],     'should of failed again, this is the first retry attempt'
    assert_equal 0, Resque.info[:pending],    '0 pending jobs, it should be in the delayed queue'

    delayed = Resque.delayed_queue_peek(0, 1)
    assert_in_delta (start_time + 60), delayed[0], 1.00, '2nd delay' # the first had a zero delay.

    5.times do
      Resque.enqueue(ExponentialBackoffJob)
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 5)
    assert_in_delta (start_time + 600),     delayed[1], 1.00, '3rd delay'
    assert_in_delta (start_time + 3600),    delayed[2], 1.00, '4th delay'
    assert_in_delta (start_time + 10_800),  delayed[3], 1.00, '5th delay'
    assert_in_delta (start_time + 21_600),  delayed[4], 1.00, '6th delay'
  end

  def test_default_backoff_strategy_with_randomness
    start_time = Time.now.to_i
    Resque.enqueue(ExponentialBackoffJobWithRandomness)

    perform_next_job @worker
    assert_equal 1, Resque.info[:processed],  '1 processed job'
    assert_equal 1, Resque.info[:failed],     'first ever run, and it should have failed, but never retried'
    assert_equal 1, Resque.info[:pending],    '1 pending job, because it never hits the scheduler'

    perform_next_job @worker
    assert_equal 2, Resque.info[:processed],  '2nd run, but first retry'
    assert_equal 2, Resque.info[:failed],     'should of failed again, this is the first retry attempt'
    assert_equal 0, Resque.info[:pending],    '0 pending jobs, it should be in the delayed queue'

    delayed = Resque.delayed_queue_peek(0, 1)
    assert_in_delta (start_time + 60), delayed[0], 3.00 * 60, '2nd delay' # the first had a zero delay.

    5.times do
      Resque.enqueue(ExponentialBackoffJobWithRandomness)
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 5)
    assert_in_delta (start_time + 600),     delayed[1], 3.00 * 600, '3rd delay'
    assert_in_delta (start_time + 3600),    delayed[2], 3.00 * 3600, '4th delay'
    assert_in_delta (start_time + 10_800),  delayed[3], 3.00 * 10_800, '5th delay'
    assert_in_delta (start_time + 21_600),  delayed[4], 3.00 * 21_600, '6th delay'
  end

  def test_custom_backoff_strategy
    start_time = Time.now.to_i
    4.times do
      Resque.enqueue(CustomExponentialBackoffJob, 'http://lividpenguin.com', 1305, 'cd8079192d379dc612f17c660591a6cfb05f1dda')
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 3)
    assert_in_delta (start_time + 10), delayed[0], 1.00, '1st delay'
    assert_in_delta (start_time + 20), delayed[1], 1.00, '2nd delay'
    assert_in_delta (start_time + 30), delayed[2], 1.00, '3rd delay'

    assert_equal 2, Resque.delayed_timestamp_size(delayed[2]), '4th delay should share delay with 3rd'

    assert_equal 4, Resque.info[:processed],  'processed jobs'
    assert_equal 4, Resque.info[:failed],     'failed jobs'
    assert_equal 0, Resque.info[:pending],    'pending jobs'
  end
end
