require 'test_helper'

class ResqueTest < Minitest::Test
  def test_resque_version
    major, minor, _ = resque_version.split('.')
    assert [1, 2].include?(major.to_i), 'major version does not match'

    if major.to_i == 1
      assert_operator minor.to_i, :>=, 25, 'minor version is too low'
    else
      assert_operator minor.to_i, :>=, 0, 'minor version is too low'
    end
  end

  def test_good_job
    clean_perform_job(GoodJob, 1234, { :cats => :maiow }, [true, false, false])

    assert_equal 0, Resque.info[:failed], 'failed jobs'
    assert_equal 1, Resque.info[:processed], 'processed job'
    assert_equal 0, Resque.delayed_queue_schedule_size
  end

  private

  def resque_version
    begin
      Resque::VERSION
    rescue NameError
      Resque::Version
    end
  end
end
