require 'resque/failure/multiple'
require 'resque/plugins/retry/logging'

module Resque
  module Failure
    # A multiple failure backend, with retry suppression
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
      include Resque::Plugins::Retry::Logging

      # Called when the job fails
      #
      # If the job will retry, suppress the failure from the other backends.
      # Store the lastest failure information in redis, used by the web
      # interface.
      #
      # @api private
      def save
        args = args_from(payload)

        log_message 'failure backend save', args, exception

        retryable = retryable?
        job_being_retried = retryable && retrying?

        if !job_being_retried
          log_message(
            "#{retryable ? '' : 'non-'}retryable job is not being retried - sending failure to superclass",
            args,
            exception
          )

          cleanup_retry_failure_log!
          return super
        end

        # some plugins define retry_delay and have it take no arguments, so rather than break those,
        # we'll just check here to see whether it takes the additional exception class argument or not
        # we also allow all job args to be passed to a custom `retry_delay` method
        retry_delay_arity = klass.method(:retry_delay).arity

        calculated_retry_delay = if [-2, 2].include?(retry_delay_arity)
          klass.retry_delay(exception.class, *args)
        elsif [-1, 1].include?(retry_delay_arity)
          klass.retry_delay(exception.class)
        else
          klass.retry_delay
        end

        if calculated_retry_delay > 0
          log_message(
            "retry_delay: #{calculated_retry_delay} > 0 - saving details in Redis",
            args,
            exception
          )

          data = {
            :failed_at => Time.now.strftime("%Y/%m/%d %H:%M:%S"),
            :payload   => payload,
            :exception => exception.class.to_s,
            :error     => exception.to_s,
            :backtrace => Array(exception.backtrace),
            :worker    => worker.to_s,
            :queue     => queue
          }
          data = Resque.encode(data)

          Resque.redis.setex(
            failure_key,
            2 * calculated_retry_delay,
            data
          )
        else
          log_message(
            "retry_delay: #{calculated_retry_delay} <= 0 - ignoring",
            args,
            exception
          )
        end
      end

      # Expose this for the hook's use
      #
      # @api public
      def self.failure_key(retry_key)
        'failure-' + retry_key
      end

      # Monkey-patch this in for now since it is a hard requirement for the
      # "retry-all" functionality to work via the Web UI.
      #
      # This can be removed when the following PR has been merged into `Resque`
      # itself:
      #
      # https://github.com/resque/resque/pull/1659
      #
      # @api public
      class_eval do |klass|
        if !klass.respond_to?(:requeue_queue)
          def klass.requeue_queue(queue)
            classes.first.requeue_queue(queue)
          end
        end
      end

      protected

      def args_from(payload)
        (payload || {})['args'].dup
      end

      def cleanup_retry_failure_log!
        Resque.redis.del(failure_key) if retryable?
      end

      def failure_key
        self.class.failure_key(retry_key)
      end

      def klass
        Resque::Job.new(nil, nil).constantize(payload['class'])
      end

      def retry_key
        klass.redis_retry_key(*payload['args'])
      end

      def retryable?
        klass.respond_to?(:redis_retry_key)
      rescue NameError
        false
      end

      def retrying?
        redis_key_exists?(retry_key)
      end

      private

      def redis_key_exists?(key)
        if Resque.redis.respond_to?(:exists?)
          begin
            Resque.redis.exists?(key)
          rescue
            ![false, 0].include?(Resque.redis.exists(key) || false)
          end
        else
          ![false, 0].include?(Resque.redis.exists(key) || false)
        end
      end
    end
  end
end
