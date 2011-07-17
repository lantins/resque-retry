require File.dirname(__FILE__) + '/test_helper'

# make sure the worlds not fallen from beneith us.
class ResqueTest < MiniTest::Unit::TestCase
  def test_resque_version
    major, minor, patch = Resque::Version.split('.')
    assert_equal 1, major.to_i, 'major version does not match'
    assert_operator minor.to_i, :>=, 8, 'minor version is too low'
  end

  def test_good_job
    clean_perform_job(GoodJob, 1234, { :cats => :maiow }, [true, false, false])

    assert_equal 0, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.delayed_queue_schedule_size
  end
end