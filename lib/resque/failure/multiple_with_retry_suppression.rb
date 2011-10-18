require 'resque/failure/multiple'

module Resque
  module Failure

    # A multiple failure backend, with retry suppression.
    #
    # For example: if you had a job that could retry 5 times, your failure 
    # backends are not notified unless the _final_ retry attempt also fails.
    #
    # Example:
    #
    #   require 'resque-retry'
    #   require 'resque/failure/redis'
    #
    #   Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
    #   Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
    #
    class MultipleWithRetrySuppression < Multiple
      include Resque::Helpers

      module CleanupHooks
        # Resque after_perform hook.
        #
        # Deletes retry failure information from Redis.
        def after_perform_retry_failure_cleanup(*args)
          retry_key = redis_retry_key(*args)
          failure_key = Resque::Failure::MultipleWithRetrySuppression.failure_key(retry_key)
          Resque.redis.del(failure_key)
        end
      end

      # Called when the job fails.
      #
      # If the job will retry, suppress the failure from the other backends.
      # Store the lastest failure information in redis, used by the web
      # interface.
      def save
        unless retryable? && retrying?
          cleanup_retry_failure_log!
          super
        else
          data = {
            :failed_at => Time.now.strftime("%Y/%m/%d %H:%M:%S"),
            :payload   => payload,
            :exception => exception.class.to_s,
            :error     => exception.to_s,
            :backtrace => Array(exception.backtrace),
            :worker    => worker.to_s,
            :queue     => queue
          }

          # Register cleanup hooks.
          unless klass.respond_to?(:after_perform_retry_failure_cleanup)
            klass.send(:extend, CleanupHooks)
          end

          redis[failure_key] = Resque.encode(data)
        end
      end

      # Expose this for the hook's use.
      def self.failure_key(retry_key)
        'failure_' + retry_key
      end

      protected
      def klass
        constantize(payload['class'])
      end

      def retry_key
        klass.redis_retry_key(payload['args'])
      end

      def failure_key
        self.class.failure_key(retry_key)
      end

      def retryable?
        klass.respond_to?(:redis_retry_key)
      rescue NameError
        false
      end

      def retrying?
        redis.exists(retry_key)
      end

      def cleanup_retry_failure_log!
        redis.del(failure_key) if retryable?
      end
    end
  end
end
