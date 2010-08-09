require 'resque/failure/multiple'

module Resque
  module Failure
    class MultipleWithRetrySuppression < Multiple
      module CleanupHooks
        def after_perform_retry_cleanup(*args)
          retry_key = redis_retry_key(*args)
          failure_key = Resque::Failure::MultipleWithRetrySuppression.
            failure_key(retry_key)
          Resque.redis.del(failure_key)
        end
      end

      include Resque::Helpers

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
          unless klass.respond_to?(:after_perform_retry_cleanup)
            klass.send(:extend, CleanupHooks)
          end

          redis[failure_key] = Resque.encode(data)
        end
      end

      # Expose this for the hook's use.
      def self.failure_key(retry_key)
        "failure_" + retry_key
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
