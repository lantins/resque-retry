require 'cgi'
require 'resque/server'
require 'resque/scheduler/server'

# Extend Resque::Server to add tabs.
module ResqueRetry
  module Server

    # Adds `resque-retry` web interface elements to `resque-web`
    #
    # @api private
    def self.included(base)
      base.class_eval {

        get '/retry' do
          erb local_template('retry.erb')
        end

        get '/retry/:timestamp' do
          erb local_template('retry_timestamp.erb')
        end

        post '/retry/:timestamp/remove' do
          Resque.delayed_timestamp_peek(params[:timestamp], 0, 0).each do |job|
            cancel_retry(job)
          end
          redirect u('retry')
        end

        post '/retry/:timestamp/jobs/:id/remove' do
          job = Resque.decode(params[:id])
          cancel_retry(job)
          redirect u("retry/#{params[:timestamp]}")
        end
      }
    end

    # Helper methods used by retry tab.
    module Helpers
      # builds a retry key for the specified job.
      def retry_key_for_job(job)
        klass = get_class(job)
        if klass && klass.respond_to?(:redis_retry_key)
          klass.redis_retry_key(job['args'])
        else
          nil
        end
      end

      # gets the number of retry attempts for a job.
      def retry_attempts_for_job(job)
        Resque.redis.get(retry_key_for_job(job))
      end

      # gets the failure details hash for a job.
      def retry_failure_details(retry_key)
        Resque.decode(Resque.redis.get("failure-#{retry_key}"))
      end

      # reads a 'local' template file.
      def local_template(path)
        # Is there a better way to specify alternate template locations with sinatra?
        File.read(File.join(File.dirname(__FILE__), "server/views/#{path}"))
      end

      # cancels job retry
      def cancel_retry(job)
        klass = get_class(job)
        if klass
          retry_key = retry_key_for_job(job)
          Resque.remove_delayed(klass, *job['args'])
          Resque.redis.del("failure-#{retry_key}")
          Resque.redis.del(retry_key)
        else
          raise 'cannot cancel, job not found'
        end
      end

      private
      def get_class(job)
        begin
          Resque::Job.new(nil, nil).constantize(job['class'])
        rescue
          nil
        end
      end
    end

  end
end

Resque::Server.tabs << 'Retry'
Resque::Server.class_eval do
  include ResqueRetry::Server
  helpers ResqueRetry::Server::Helpers
end
