# Extend Resque::Server to add tabs
module ResqueRetry

  module Server

    def self.included(base)
      base.class_eval do


        get "/retry" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/retry.erb'))
        end

        get "/retry/:timestamp" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/retry_timestamp.erb'))
        end


      end

    end


  end

end

Resque::Server.tabs << 'Retry'

Resque::Server.class_eval do
  include ResqueRetry::Server
end