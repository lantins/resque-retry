require File.dirname(__FILE__) + '/test_helper'

class RetryInheritingChecksTest < MiniTest::Unit::TestCase
  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def test_default_job_has_one_exception
    assert_equal 0, RetryDefaultsJob.retry_criteria_checks.size
  end

  def test_inheriting_copies_exceptions
    assert_equal RetryDefaultsJob.retry_criteria_checks, InheritTestJob.retry_criteria_checks
  end

  def test_inheriting_adds_exceptions
    assert_equal 1, InheritTestWithExtraJob.retry_criteria_checks.size
  end

  def test_extending_with_resque_retry_doesnt_override_previously_defined_inherited_hook
    klass = InheritOrderingJobExtendLastSubclass
    assert_equal 1, klass.retry_criteria_checks.size
    assert_equal 'test', klass.test_value
  end

  def test_extending_with_resque_retry_then_defining_inherited_does_not_override_previous_hook
    klass = InheritOrderingJobExtendFirstSubclass
    assert_equal 1, klass.retry_criteria_checks.size
    assert_equal 'test', klass.test_value
  end
end
