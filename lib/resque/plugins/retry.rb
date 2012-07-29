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
    #     def self.retry_identifier(url, hook_id, hmac_key)
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
      #
      # @api private
      def inherited(subclass)
        super(subclass)
        subclass.instance_variable_set("@retry_criteria_checks", retry_criteria_checks.dup)
      end

      # @abstract You may override to implement a custom retry identifier,
      #           you should consider doing this if your job arguments
      #           are many/long or may not cleanly convert to strings.
      #
      # Builds a retry identifier using the job arguments. This identifier
      # is used as part of the redis key
      #
      # @param [Array] args job arguments
      # @return [String] job identifier
      #
      # @api public
      def retry_identifier(*args)
        args_string = args.join('-')
        args_string.empty? ? nil : args_string
      end

      # Builds the redis key to be used for keeping state of the job
      # attempts.
      #
      # @return [String] redis key
      #
      # @api public
      def redis_retry_key(*args)
        ['resque-retry', name, retry_identifier(*args)].compact.join(":").gsub(/\s/, '')
      end

      # Maximum number of retrys we can attempt to successfully perform the job
      #
      # A retry limit of 0 will *never* retry.
      # A retry limit of -1 or below will retry forever.
      #
      # @return [Fixnum]
      #
      # @api public
      def retry_limit
        @retry_limit ||= 1
      end

      # Number of retry attempts used to try and perform the job
      #
      # The real value is kept in Redis, it is accessed and incremented using
      # a before_perform hook.
      #
      # @return [Fixnum] number of attempts
      #
      # @api public
      def retry_attempt
        @retry_attempt ||= 0
      end

      # @abstract
      # Number of seconds to delay until the job is retried
      #
      # @return [Number] number of seconds to delay
      #
      # @api public
      def retry_delay(exception_class = nil)
        if @retry_exceptions.is_a?(Hash)
          delay = @retry_exceptions[exception_class] || 0
          # allow an array of delays.
          delay.is_a?(Array) ? delay[retry_attempt] || delay.last : delay
        else
          @retry_delay ||= 0
        end
      end

      # @abstract
      # Number of seconds to sleep after job is requeued
      # 
      # @return [Number] number of seconds to sleep
      #
      # @api public
      def sleep_after_requeue
        @sleep_after_requeue ||= 0
      end

      # @abstract
      # Specify another resque job (module or class) to delegate retry duties
      # to upon failure
      #
      # @return [Object, nil] class or module if delegate on failure, otherwise nil
      #
      # @api public
      def retry_job_delegate
        @retry_job_delegate ||= nil
      end

      # @abstract
      # Modify the arguments used to retry the job. Use this to do something
      # other than try the exact same job again
      #
      # @return [Array] new job arguments
      #
      # @api public
      def args_for_retry(*args)
        args
      end

      # Convenience method to test whether you may retry on a given
      # exception
      #
      # @param [Exception] an instance of Exception. Deprecated: can
      # also be a Class
      #
      # @return [Boolean]
      #
      # @api public
      def retry_exception?(exception)
        return true if retry_exceptions.nil?
        !! retry_exceptions.any? do |ex|
          if exception.is_a?(Class)
            ex >= exception
          else
            ex === exception
          end
        end
      end

      # @abstract
      # Controls what exceptions may be retried
      #
      # Default: `nil` - this will retry all exceptions.
      #
      # @return [Array, nil]
      #
      # @api public
      def retry_exceptions
        if @retry_exceptions.is_a?(Hash)
          @retry_exceptions.keys
        else
          @retry_exceptions ||= nil
        end
      end

      # Test if the retry criteria is valid
      #
      # @param [Exception] exception
      # @param [Array] args job arguments
      # @return [Boolean]
      #
      # @api public
      def retry_criteria_valid?(exception, *args)
        # if the retry limit was reached, dont bother checking anything else.
        return false if retry_limit_reached?

        # We always want to retry if the exception matches.
        should_retry = retry_exception?(exception)

        # call user retry criteria check blocks.
        retry_criteria_checks.each do |criteria_check|
          should_retry ||= !!instance_exec(exception, *args, &criteria_check)
        end

        should_retry
      end

      # Retry criteria checks
      #
      # @return [Array]
      #
      # @api public
      def retry_criteria_checks
        @retry_criteria_checks ||= []
      end

      # Test if the retry limit has been reached
      #
      # @return [Boolean]
      #
      # @api public
      def retry_limit_reached?
        if retry_limit == 0
          true
        elsif retry_limit > 0
          true if retry_attempt >= retry_limit
        else
          false
        end
      end

      # Register a retry criteria check callback to be run before retrying
      # the job again
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
      #
      # @api public
      def retry_criteria_check(&block)
        retry_criteria_checks << block
      end

      # Retries the job
      #
      # @api private
      def try_again(exception, *args)
        # some plugins define retry_delay and have it take no arguments, so rather than break those,
        # we'll just check here to see whether it takes the additional exception class argument or not
        temp_retry_delay = ([-1, 1].include?(method(:retry_delay).arity) ? retry_delay(exception.class) : retry_delay)

        retry_in_queue = retry_job_delegate ? retry_job_delegate : self
        if temp_retry_delay <= 0
          # If the delay is 0, no point passing it through the scheduler
          Resque.enqueue(retry_in_queue, *args_for_retry(*args))
        else
          Resque.enqueue_in(temp_retry_delay, retry_in_queue, *args_for_retry(*args))
        end

        # remove retry key from redis if we handed retry off to another queue.
        clean_retry_key(*args) if retry_job_delegate

        # sleep after requeue if enabled.
        sleep(sleep_after_requeue) if sleep_after_requeue > 0
      end

      # Resque before_perform hook
      #
      # Increments and sets the `@retry_attempt` count.
      #
      # @api private
      def before_perform_retry(*args)
        @on_failure_retry_hook_already_called = false

        # store number of retry attempts.
        retry_key = redis_retry_key(*args)
        Resque.redis.setnx(retry_key, -1)             # default to -1 if not set.
        @retry_attempt = Resque.redis.incr(retry_key) # increment by 1.
      end

      # Resque after_perform hook
      #
      # Deletes retry attempt count from Redis.
      #
      # @api private
      def after_perform_retry(*args)
        clean_retry_key(*args)
      end

      # Resque on_failure hook
      #
      # Checks if our retry criteria is valid, if it is we try again.
      # Otherwise the retry attempt count is deleted from Redis.
      #
      # @note This hook will only allow execution once per job perform attempt.
      #       This was added because Resque v1.20.0 calls the hook twice.
      #       IMO; this isn't something resque-retry should have to worry about!
      #
      # @api private
      def on_failure_retry(exception, *args)
        return if @on_failure_retry_hook_already_called

        if retry_criteria_valid?(exception, *args)
          try_again(exception, *args)
        else
          clean_retry_key(*args)
        end

        @on_failure_retry_hook_already_called = true
      end

      # Used to perform retry criteria check blocks under the job instance's context
      #
      # @return [Object] return value of the criteria check
      #
      # @api private
      def instance_exec(*args, &block)
        mname = "__instance_exec_#{Thread.current.object_id.abs}"
        class << self; self end.class_eval{ define_method(mname, &block) }
        begin
          ret = send(mname, *args)
        ensure
          class << self; self end.class_eval{ undef_method(mname) } rescue nil
        end
        ret
      end

      # Clean up retry state from redis once done
      #
      # @api private
      def clean_retry_key(*args)
        Resque.redis.del(redis_retry_key(*args))
      end

    end
  end
end
