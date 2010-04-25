module Resque
  module Plugins
    module Retry
      def identifier(*args)
        args.join('-')
      end

      def key(*args)
        ['resque-retry', name, identifier(*args)].compact.join(":")
      end

      # 0 = retry forever
      def retry_limit
        @retry_limit ||= 1
      end

      def retry_attempt
        @retry_attempt ||= 0
      end

      def seconds_until_retry
        @seconds_until_retry ||= 0
      end

      def args_for_retry(*args)
        args
      end

      def retry_exception?(exception)
        return true if retry_exceptions.nil?
        !! retry_exceptions.any? { |ex| ex >= exception }
      end

      def retry_exceptions
        @retry_exceptions ||= nil
      end

      # at some point let people extend the criteria? give the user a chance
      # to say no.
      def retry_criteria_valid?(exception, *args)
        if retry_limit > 0
          return false if retry_attempt >= retry_limit
        end
        retry_exception?(exception.class)
      end

      def try_again(*args)
        if Resque.respond_to?(:enqueue_in) && seconds_until_retry > 0
          Resque.enqueue_in(seconds_until_retry, self, *args_for_retry(*args))
        else
          sleep(seconds_until_retry) if seconds_until_retry > 0
          Resque.enqueue(self, *args_for_retry(*args))
        end
      end

      def before_perform_retry(*args)
        Resque.redis.setnx(key(*args), -1)             # default to -1 if not set.
        @retry_attempt = Resque.redis.incr(key(*args)) # increment by 1.
      end

      def after_perform_retry(*args)
        Resque.redis.del(key(*args))
      end

      def on_failure_retry(exception, *args)
        try_again(*args) if retry_criteria_valid?(exception, *args)
      end
    end

  end
end