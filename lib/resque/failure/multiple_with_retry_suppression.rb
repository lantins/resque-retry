require 'resque/failure/multiple'

module Resque
  module Failure
    class MultipleWithRetrySuppression < Multiple
      include Resque::Helpers

      def save
        unless retryable? && retrying?
          super
        end
      end

      protected
      def klass
        constantize(payload['class'])
      end

      def retry_key
        klass.redis_retry_key(payload['args'])
      end

      def failure_key
        "failure_#{retry_key}"
      end

      def retryable?
        klass.respond_to?(:redis_retry_key)
      end

      def retrying?
        redis.get(retry_key)
      end
    end
  end
end
