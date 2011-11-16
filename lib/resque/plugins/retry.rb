module Resque
  module Plugins

    # If you want your job to retry on failure, simply extend your module/class
    # with this module:
    #
    #   class DeliverWebHook
    #     extend Resque::Plugins::Retry # allows 1 retry by default.
    #     @queue = :web_hooks
    #
    #     def self.perform(url, hook_id, hmac_key)
    #       heavy_lifting
    #     end
    #   end
    #
    # Easily do something custom:
    #
    #   class DeliverWebHook
    #     extend Resque::Plugins::Retry
    #     @queue = :web_hooks
    #
    #     @retry_limit = 8  # default: 1
    #     @retry_delay = 60 # default: 0
    #
    #     # used to build redis key, for counting job attempts.
    #     def self.identifier(url, hook_id, hmac_key)
    #       "#{url}-#{hook_id}"
    #     end
    #
    #     def self.perform(url, hook_id, hmac_key)
    #       heavy_lifting
    #     end
    #   end
    #
    module Retry

      # Copy retry criteria checks on inheritance.
      def inherited(subclass)
        super(subclass)
        subclass.instance_variable_set("@retry_criteria_checks", retry_criteria_checks.dup)
      end

      # @abstract You may override to implement a custom identifier,
      #           you should consider doing this if your job arguments
      #           are many/long or may not cleanly cleanly to strings.
      #
      # Builds an identifier using the job arguments. This identifier
      # is used as part of the redis key.
      #
      # @param [Array] args job arguments
      # @return [String] job identifier
      def identifier(*args)
        args_string = args.join('-')
        args_string.empty? ? nil : args_string
      end

      # Builds the redis key to be used for keeping state of the job
      # attempts.
      #
      # @return [String] redis key
      def redis_retry_key(*args)
        ['resque-retry', name, identifier(*args)].compact.join(":").gsub(/\s/, '')
      end

      # Maximum number of retrys we can attempt to successfully perform the job.
      # A retry limit of 0 or below will retry forever.
      #
      # @return [Fixnum]
      def retry_limit
        @retry_limit ||= 1
      end

      # Number of retry attempts used to try and perform the job.
      #
      # The real value is kept in Redis, it is accessed and incremented using
      # a before_perform hook.
      #
      # @return [Fixnum] number of attempts
      def retry_attempt
        @retry_attempt ||= 0
      end

      # @abstract
      # Number of seconds to delay until the job is retried.
      # 
      # @return [Number] number of seconds to delay
      def retry_delay(exception_class = nil)
        if @retry_delay.is_a?(Hash)
          @retry_delay[exception_class] ||= 0
        else
          @retry_delay ||= 0
        end
      end

      # @abstract
      # Modify the arguments used to retry the job. Use this to do something
      # other than try the exact same job again.
      #
      # @return [Array] new job arguments
      def args_for_retry(*args)
        args
      end

      # Convenience method to test whether you may retry on a given exception.
      #
      # @return [Boolean]
      def retry_exception?(exception)
        return true if retry_exceptions.nil?
        !! retry_exceptions.any? { |ex| ex >= exception }
      end

      # @abstract
      # Controls what exceptions may be retried.
      #
      # Default: `nil` - this will retry all exceptions.
      # 
      # @return [Array, nil]
      def retry_exceptions
        @retry_exceptions ||= nil
      end

      # Test if the retry criteria is valid.
      #
      # @param [Exception] exception
      # @param [Array] args job arguments
      # @return [Boolean]
      def retry_criteria_valid?(exception, *args)
        # if the retry limit was reached, dont bother checking anything else.
        return false if retry_limit_reached?

        # We always want to retry if the exception matches.
        should_retry = retry_exception?(exception.class)

        # call user retry criteria check blocks.
        retry_criteria_checks.each do |criteria_check|
          should_retry ||= !!criteria_check.call(exception, *args)
        end

        should_retry
      end

      # Retry criteria checks.
      #
      # @return [Array]
      def retry_criteria_checks
        @retry_criteria_checks ||= []
        @retry_criteria_checks
      end

      # Test if the retry limit has been reached.
      #
      # @return [Boolean]
      def retry_limit_reached?
        if retry_limit > 0
          return true if retry_attempt >= retry_limit
        end
        false
      end

      # Register a retry criteria check callback to be run before retrying
      # the job again.
      #
      # If any callback returns `true`, the job will be retried.
      #
      # @example Using a custom retry criteria check.
      #
      #   retry_criteria_check do |exception, *args|
      #     if exception.message =~ /InvalidJobId/
      #       # don't retry if we got passed a invalid job id.
      #       false
      #     else
      #       true
      #     end
      #   end
      #
      # @yield [exception, *args]
      # @yieldparam exception [Exception] the exception that was raised
      # @yieldparam args [Array] job arguments
      # @yieldreturn [Boolean] false == dont retry, true = can retry
      def retry_criteria_check(&block)
        retry_criteria_checks << block
      end

      # Will retry the job.
      def try_again(exception, *args)
        # some plugins define retry_delay and have it take no arguments, so rather than break those,
        # we'll just check here to see whether it takes the additional exception class argument or not
        my_retry_delay = ([-1, 1].include?(method(:retry_delay).arity) ? retry_delay(exception.class) : retry_delay)
        if my_retry_delay <= 0
          # If the delay is 0, no point passing it through the scheduler
          Resque.enqueue(self, *args_for_retry(*args))
        else
          Resque.enqueue_in(my_retry_delay, self, *args_for_retry(*args))
        end
      end

      # Resque before_perform hook.
      #
      # Increments and sets the `@retry_attempt` count.
      def before_perform_retry(*args)
        retry_key = redis_retry_key(*args)
        Resque.redis.setnx(retry_key, -1)             # default to -1 if not set.
        @retry_attempt = Resque.redis.incr(retry_key) # increment by 1.
      end

      # Resque after_perform hook.
      #
      # Deletes retry attempt count from Redis.
      def after_perform_retry(*args)
        Resque.redis.del(redis_retry_key(*args))
      end

      # Resque on_failure hook.
      #
      # Checks if our retry criteria is valid, if it is we try again.
      # Otherwise the retry attempt count is deleted from Redis.
      def on_failure_retry(exception, *args)
        if retry_criteria_valid?(exception, *args)
          try_again(exception, *args)
        else
          Resque.redis.del(redis_retry_key(*args))
        end
      end

    end
  end
end
