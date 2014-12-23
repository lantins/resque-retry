require 'test_helper'
require 'resque-retry/server'

ENV['RACK_ENV'] = ENV['RAILS_ENV']

# Testing the Resque web interface additions.
class ServerTest < MiniTest::Test
  include Rack::Test::Methods

  def setup
    Resque.redis.flushall
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
  end

  def app
    Resque::Server
  end

  # make sure the world looks okay first =)
  def test_were_able_to_access_normal_resque_web_overview
    get '/overview'
    assert_equal 200, last_response.status, 'HTTP status code should be 200'
  end

  def test_should_include_retry_tab
    get '/overview'
    assert last_response.body.include?('/retry')
  end

  def test_display_retry_job
    # to begin with, we should have no retry jobs listed.
    get '/retry'
    assert last_response.body.include?('<b>0</b> timestamps'), 'should have 0 retry jobs'

    # queue failing job that will retry.
    Resque.enqueue(LimitThreeJobDelay1Hour)
    perform_next_job(@worker)

    # we should now have the retry job listed.
    get '/retry'
    assert last_response.body.include?('<b>1</b> timestamps'), 'should have 1 retry jobs'
  end
end
