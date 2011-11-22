require File.dirname(__FILE__) + '/test_helper'

require 'resque-retry/server'
ENV['RACK_ENV'] = 'test'

# Testing the Resque web interface additions.
class ServerTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods

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

end