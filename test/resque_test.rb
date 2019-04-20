require 'test_helper'

# make sure the worlds not fallen from beneith us.
class ResqueTest < Minitest::Test
  def test_resque_version
    major, minor, patch = Resque::Version.split('.')
    assert_equal 2, major.to_i, 'major version does not match'
    assert_operator minor.to_i, :>=, 0, 'minor version is too low'
  end

  def test_good_job
    clean_perform_job(GoodJob, 1234, { :cats => :maiow }, [true, false, false])

    assert_equal 0, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.delayed_queue_schedule_size
  end
end
