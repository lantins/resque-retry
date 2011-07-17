require 'sinatra/base'

class ResqueRetryExampleApp < Sinatra::Base
  # Sinatra Settings
  set :root, Dir.pwd
  enable :raise_errors

  get '/' do
    @info = Resque.info
    erb :index
  end

  post '/' do
    Resque.enqueue(SuccessfulJob, Random.rand(10000))
    redirect "/"
  end
  
  post '/failing' do 
    Resque.enqueue(FailingJob, Random.rand(10000))
    redirect "/"
  end

  post '/failing-with-retry' do 
    Resque.enqueue(FailingWithRetryJob, Random.rand(10000))
    redirect "/"
  end
end