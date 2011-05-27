# Extend Resque::Server to add tabs.
module ResqueRetry
  module Server

    def self.included(base)
      base.class_eval {
        helpers do
          # builds a retry key for the specified job.
          def retry_key_for_job(job)
            klass = Resque.constantize(job['class'])
            if klass.respond_to?(:redis_retry_key)
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
            Resque.decode(Resque.redis["failure_#{retry_key}"])
          end

          # reads a 'local' template file.
          def local_template(path)
            # Is there a better way to specify alternate template locations with sinatra?
            File.read(File.join(File.dirname(__FILE__), "server/views/#{path}"))
          end

          # Cancels job retry
          #
          def cancel_retry(job)
            klass = Resque.constantize(job['class'])
            retry_key = retry_key_for_job(job)
            Resque.remove_delayed(klass, *job["args"])
            Resque.redis.del("failure_#{retry_key}")
            Resque.redis.del(retry_key)
          end
        end

        get '/retry' do
          erb local_template('retry.erb')
        end

        get '/retry/:timestamp' do
          erb local_template('retry_timestamp.erb')
        end

        post "/retry/:timestamp/remove" do
          Resque.delayed_timestamp_peek(params[:timestamp], 0, 0).each do |job|
            cancel_retry(job)
          end
          redirect u("retry")
        end

        post "/retry/:timestamp/jobs/:id/remove" do
          job = Resque.decode(params[:id])
          cancel_retry(job)
          redirect u("retry/#{params[:timestamp]}")
        end
      }
    end

  end
end

Resque::Server.tabs << 'Retry'
Resque::Server.class_eval do
  include ResqueRetry::Server
end
