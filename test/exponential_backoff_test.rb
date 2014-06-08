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
    assert_in_delta (start_time + 60*1.1), delayed[0], 7.00, '2nd delay' # the first had a zero delay.

    5.times do
      Resque.enqueue(ExponentialBackoffJob)
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 5)
    assert_in_delta (start_time + 600*1.1),     delayed[1], 61.00, '3rd delay'
    assert_in_delta (start_time + 3600*1.1),    delayed[2], 361.00, '4th delay'
    assert_in_delta (start_time + 10_800*1.1),  delayed[3], 1081.00, '5th delay'
    assert_in_delta (start_time + 21_600*1.1),  delayed[4], 2161.00, '6th delay'
  end

  def test_dont_allow_both_retry_and_ignore_exceptions
    job_types = [
      InvalidRetryDelayMaxConfigurationJob,
      InvalidRetryDelayMinAndMaxConfigurationJob,
      InvalidRetryDelayMinConfigurationJob,
    ]

    job_types.each do |job_type|
      assert_raises Resque::Plugins::ExponentialBackoff::InvalidRetryDelayMultiplicandConfigurationException do
        job_type.extend(Resque::Plugins::ExponentialBackoff)
      end
    end
  end

  def test_default_backoff_strategy_with_retry_delay_multiplicands
    job_types = [
      ExponentialBackoffWithRetryDelayMultiplicandMaxJob,
      ExponentialBackoffWithRetryDelayMultiplicandMinJob,
      ExponentialBackoffWithRetryDelayMultiplicandMinAndMaxJob,
    ]

    job_types.each do |job_type|
      # all of these values are used heavily in assertions below
      start_time = Time.now.to_i
      multiplicand_min = job_type.public_send(:retry_delay_multiplicand_min)
      multiplicand_max = job_type.public_send(:retry_delay_multiplicand_max)

      Resque.enqueue(job_type)

      # first attempt, failed but never retried
      perform_next_job(@worker)
      assert_equal 1, Resque.info[:pending]
      assert_equal 1, Resque.info[:processed]
      assert_equal 1, Resque.info[:failed]

      # second attempt, first retry, should fail again
      perform_next_job(@worker)
      assert_equal 0, Resque.info[:pending]
      assert_equal 2, Resque.info[:processed]
      assert_equal 2, Resque.info[:failed]

      # second delay
      delayed = Resque.delayed_queue_peek(0, 1)
      assert_in_delta(
        start_time + 60 * multiplicand_min,
        delayed[0],
        60 * multiplicand_max
      )

      5.times do
        Resque.enqueue(job_type)
        perform_next_job(@worker)
      end

      # third through sixth delays
      delayed = Resque.delayed_queue_peek(1, 5)
      [600, 3600, 10_800, 21_600].each_with_index do |delay, index|
        assert_in_delta(
          start_time + delay * multiplicand_min,
          delayed[index],
          delay * multiplicand_max
        )
      end

      # always reset the state before the next test case is run
      Resque.redis.flushall
    end
  end

  def test_custom_backoff_strategy
    start_time = Time.now.to_i
    4.times do
      Resque.enqueue(CustomExponentialBackoffJob, 'http://lividpenguin.com', 1305, 'cd8079192d379dc612f17c660591a6cfb05f1dda')
      perform_next_job @worker
    end

    delayed = Resque.delayed_queue_peek(0, 3)
    assert_in_delta (start_time + 10*1.1), delayed[0], 2.00, '1st delay'
    assert_in_delta (start_time + 20*1.1), delayed[1], 3.00, '2nd delay'
    assert_in_delta (start_time + 30*1.1), delayed[2], 4.00, '3rd delay'
    assert_in_delta (start_time + 30*1.1), delayed[3], 4.00, '4th delay should share delay with 3rd'

    assert_equal 4, Resque.info[:processed],  'processed jobs'
    assert_equal 4, Resque.info[:failed],     'failed jobs'
    assert_equal 0, Resque.info[:pending],    'pending jobs'
  end
end
