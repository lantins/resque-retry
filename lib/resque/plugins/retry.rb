require 'digest/sha1'
require 'resque/plugins/retry/logging'

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
      include Resque::Plugins::Retry::Logging

      # Raised if the retry-strategy cannot be determined or has conflicts
      #
      # @api public
      class AmbiguousRetryStrategyException < StandardError; end

      # Raised if there is a problem with the configuration of resque-retry.
      #
      # @api public
      class RetryConfigurationException < StandardError; end

      # Fail fast, when extended, if the "receiver" is misconfigured
      #
      # @api private
      def self.extended(receiver)
        retry_exceptions = receiver.instance_variable_get('@retry_exceptions')
        fatal_exceptions = receiver.instance_variable_get('@fatal_exceptions')

        if fatal_exceptions && retry_exceptions
          raise AmbiguousRetryStrategyException.new(%{You can't define both "@fatal_exceptions" and "@retry_exceptions"})
        end
      end

      # Copy retry criteria checks, try again callbacks, and give up callbacks
      # on inheritance.
      #
      # @api private
      def inherited(subclass)
        super(subclass)
        subclass.instance_variable_set('@retry_criteria_checks', retry_criteria_checks.dup)
        subclass.instance_variable_set('@try_again_callbacks', try_again_callbacks.dup)
        subclass.instance_variable_set('@give_up_callbacks', give_up_callbacks.dup)
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
        args_string.empty? ? nil : Digest::SHA1.hexdigest(args_string)
      end

      # Builds the redis key to be used for keeping state of the job
      # attempts.
      #
      # @return [String] redis key
      #
      # @api public
      def redis_retry_key(*args)
        ['resque-retry', name, retry_identifier(*args)].compact.join(':').gsub(/\s/, '')
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
      # If @retry_exceptions is a Hash and there is no delay defined for exception_class,
      # looks for closest superclass and assigns it's delay to @retry_exceptions[exception_class]
      #
      # @return [Number] number of seconds to delay
      #
      # @api public
      def retry_delay(exception_class = nil)
        if @retry_exceptions.is_a?(Hash)
          delay = @retry_exceptions[exception_class] ||= begin
            relevant_definitions = @retry_exceptions.select { |ex| exception_class <= ex }
            relevant_definitions.any? ? relevant_definitions.sort.first[1] : 0
          end
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
      # Specify the queue that the job should be placed in upon failure
      #
      # @return [Symbol] Symbol representing queue that job should be placed in
      #
      # @api public
      def retry_queue(exception, *args)
        nil
      end

      # @abstract
      # Modify the arguments used to retry the job. Use this to do something
      # other than try the exact same job again
      #
      # @return [Array] new job arguments
      #
      # @api public
      def retry_args(*args)
        # Here for backwards compatibility. If an "args_for_retry" method exists
        # invoke it, but warn that it is deprecated (and will be removed in a
        # future revision)
        if respond_to?(:args_for_retry)
          warn "`Resque::Plugins::Retry#args_for_retry` is deprecated, please use `Resque::Plugins::Retry#retry_args` instead."
          args_for_retry(*args)
        else
          args
        end
      end

      # @abstract
      # Modify the arguments used to retry the job based on the exception.
      # Use this to do something other than try the exact same job again.
      #
      # @return [Array] new job arguments
      #
      # @api public
      def retry_args_for_exception(exception, *args)
        retry_args(*args)
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
        # If both "fatal_exceptions" and "retry_exceptions" are undefined we are
        # done (we should retry the exception)
        #
        # It is intentional that we check "retry_exceptions" first since it is
        # more likely that it will be defined (over "fatal_exceptions") as it
        # has been part of the API for quite a while
        return true if retry_exceptions.nil? && fatal_exceptions.nil?

        # If "fatal_exceptions" is undefined interrogate "retry_exceptions"
        if fatal_exceptions.nil?
          retry_exceptions.any? do |ex|
            if exception.is_a?(Class)
              ex >= exception
            else
              ex === exception
            end
          end
        # It is safe to assume we need to check "fatal_exceptions" at this point
        else
          fatal_exceptions.none? do |ex|
            if exception.is_a?(Class)
              ex >= exception
            else
              ex === exception
            end
          end
        end
      end

      # @abstract
      # Controls what exceptions may not be retried
      #
      # Default: `nil` - this will retry all exceptions.
      #
      # @return [Array, nil]
      #
      # @api public
      attr_reader :fatal_exceptions

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

      # @abstract
      # The number of seconds to set the TTL to on the resque-retry key in redis
      #
      # @return [Number] number of seconds
      #
      # @api public
      attr_reader :expire_retry_key_after

      # Test if the retry criteria is valid
      #
      # @param [Exception] exception
      # @param [Array] args job arguments
      # @return [Boolean]
      #
      # @api public
      def retry_criteria_valid?(exception, *args)
        # if the retry limit was reached, dont bother checking anything else.
        if retry_limit_reached?
          log_message 'retry limit reached', args, exception
          return false
        end

        # We always want to retry if the exception matches.
        retry_based_on_exception = retry_exception?(exception)
        log_message "Exception is #{retry_based_on_exception ? '' : 'not '}sufficient for a retry", args, exception

        retry_based_on_criteria = false
        unless retry_based_on_exception
          # call user retry criteria check blocks.
          retry_based_on_criteria = retry_criteria_checks_pass?(exception, *args)
          log_message "user retry criteria is #{retry_based_on_criteria ? '' : 'not '}sufficient for a retry", args, exception
        end

        retry_based_on_exception || retry_based_on_criteria
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
      # the job again. Can be registered with a block or a symbol.
      #
      # If any callback returns `true`, the job will be retried.
      #
      # @example Registering a custom retry criteria check.
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
      # @example
      #
      #   retry_criteria_check :my_check
      #
      # @param [Symbol?] method
      # @yield [exception, *args]
      # @yieldparam exception [Exception] the exception that was raised
      # @yieldparam args [Array] job arguments
      # @yieldreturn [Boolean] false == dont retry, true == can retry
      #
      # @api public
      def retry_criteria_check(method=nil, &block)
        if method.is_a? Symbol
          retry_criteria_checks << method
        elsif block_given?
          retry_criteria_checks << block
        end
      end

      # Returns true if *any* of the retry criteria checks pass. When a retry
      # criteria check passes, the remaining ones are not executed.
      #
      # @returns [Boolean] whether any of the retry criteria checks pass
      #
      # @api private
      def retry_criteria_checks_pass?(exception, *args)
        retry_criteria_checks.each do |criteria_check|
          return true if !!call_symbol_or_block(criteria_check, exception, *args)
        end
        false
      end

      # Retries the job
      #
      # @api private
      def try_again(exception, *args)
        log_message 'try_again', args, exception
        run_try_again_callbacks(exception, *args)

        # some plugins define retry_delay and have it take no arguments, so rather than break those,
        # we'll just check here to see whether it takes the additional exception class argument or not
        # we also allow all job args to be passed to a custom `retry_delay` method
        retry_delay_arity = method(:retry_delay).arity

        temp_retry_delay = if [-2, 2].include?(retry_delay_arity)
          retry_delay(exception.class, *args)
        elsif [-1, 1].include?(retry_delay_arity)
          retry_delay(exception.class)
        else
          retry_delay
        end

        retry_job_class = retry_job_delegate ? retry_job_delegate : self

        retry_in_queue = retry_queue(exception, *args)
        retry_in_queue ||= Resque.queue_from_class(retry_job_class)

        log_message "retry delay: #{temp_retry_delay} for queue: #{retry_in_queue}", args, exception

        # remember that this job is now being retried. before_perform_retry will increment
        # this so it represents the retry count, and MultipleWithRetrySuppression uses
        # the existence of this to determine if the job should be sent to the
        # parent failure backend (e.g. failed queue) or not.  Removing this means
        # jobs that fail before ::perform will be both retried and sent to the failed queue.
        Resque.redis.setnx(redis_retry_key(*args), -1)

        retry_args = retry_args_for_exception(exception, *args)

        if temp_retry_delay <= 0
          # If the delay is 0, no point passing it through the scheduler
          Resque.enqueue_to(retry_in_queue, retry_job_class, *retry_args)
        else
          Resque.enqueue_in_with_queue(retry_in_queue, temp_retry_delay, retry_job_class, *retry_args)
        end

        # remove retry key from redis if we handed retry off to another queue.
        clean_retry_key(*args) if retry_job_delegate

        # sleep after requeue if enabled.
        sleep(sleep_after_requeue) if sleep_after_requeue > 0
      end

      # We failed and we're not retrying.
      #
      # @api private
      def give_up(exception, *args)
        log_message 'retry criteria not sufficient for retry', args, exception
        run_give_up_callbacks(exception, *args)
        clean_retry_key(*args)
      end

      # Resque before_perform hook
      #
      # Increments `@retry_attempt` count and updates the "retry_key" expiration
      # time (if applicable)
      #
      # @api private
      def before_perform_retry(*args)
        return if Resque.inline?
        log_message 'before_perform_retry', args
        @on_failure_retry_hook_already_called = false

        # store number of retry attempts.
        retry_key = redis_retry_key(*args)
        Resque.redis.setnx(retry_key, -1)
        @retry_attempt = Resque.redis.incr(retry_key)
        log_message "attempt: #{@retry_attempt} set in Redis", args

        # set/update the "retry_key" expiration
        if expire_retry_key_after
          log_message "updating expiration for retry key: #{retry_key}", args
          Resque.redis.expire(retry_key, retry_delay + expire_retry_key_after)
        end
      end

      # Resque after_perform hook
      #
      # Deletes retry attempt count from Redis.
      #
      # @api private
      def after_perform_retry(*args)
        return if Resque.inline?
        log_message 'after_perform_retry, clearing retry key', args
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
        return if Resque.inline?
        log_message 'on_failure_retry', args, exception
        if exception.is_a?(Resque::DirtyExit)
          # This hook is called from a worker processes, not the job process
          # that failed with a DirtyExit, so @retry_attempt wasn't set yet
          @retry_attempt = Resque.redis.get(redis_retry_key(*args)).to_i
        elsif @on_failure_retry_hook_already_called
          log_message 'on_failure_retry_hook_already_called', args, exception
          return
        end

        # If we are "ignoring" the exception, then we decrement the retry
        # counter, so that the current attempt didn't count toward the retry
        # counter.
        if ignore_exceptions.include?(exception.class)
          @retry_attempt = Resque.redis.decr(redis_retry_key(*args))
        end

        if retry_criteria_valid?(exception, *args)
          try_again(exception, *args)
        else
          give_up(exception, *args)
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
        log_message 'clean_retry_key', args
        Resque.redis.del(redis_retry_key(*args))
      end

      # Returns the try again callbacks.
      #
      # @return [Array<Proc>]
      #
      # @api public
      def try_again_callbacks
        @try_again_callbacks ||= []
      end

      # Register a try again callback that will be called when the job fails
      # but is trying again. Can be registered with a block or a symbol.
      #
      # @example Registering a callback with a block
      #
      #   try_again_callback do |exception, *args|
      #     logger.error(
      #       "Resque job received exception #{exception} and is trying again")
      #   end
      #
      # @example Registering a callback with a Symbol
      #
      #   try_again_callback :my_callback
      #
      # @param [Symbol?] method
      # @yield [exception, *args]
      # @yieldparam exception [Exception] the exception that was raised
      # @yieldparam args [Array] job arguments
      #
      # @api public
      def try_again_callback(method=nil, &block)
        if method.is_a? Symbol
          try_again_callbacks << method
        elsif block_given?
          try_again_callbacks << block
        end
      end

      # Runs all the try again callbacks.
      #
      # @param exception [Exception]
      # @param args [Object...]
      #
      # @api private
      def run_try_again_callbacks(exception, *args)
        try_again_callbacks.each do |callback|
          call_symbol_or_block(callback, exception, *args)
        end
      end

      # Returns the give up callbacks.
      #
      # @return [Array<Proc>]
      #
      # @api public
      def give_up_callbacks
        @give_up_callbacks ||= []
      end

      # Register a give up callback that will be called when the job fails
      # and is not retrying. Can be registered with a block or a symbol.
      #
      # @example Registering a callback with a block
      #
      #   give_up_callback do |exception, *args|
      #     logger.error(
      #       "Resque job received exception #{exception} and is giving up")
      #   end
      #
      # @example Registering a callback with a Symbol
      #
      #   give_up_callback :my_callback
      #
      # @param [Symbol?] method
      # @yield [exception, *args]
      # @yieldparam exception [Exception] the exception that was raised
      # @yieldparam args [Array] job arguments
      #
      # @api public
      def give_up_callback(method=nil, &block)
        if method.is_a? Symbol
          give_up_callbacks << method
        elsif block_given?
          give_up_callbacks << block
        end
      end

      # Runs all the give up callbacks.
      #
      # @param exception [Exception]
      # @param args [Object...]
      #
      # @api private
      def run_give_up_callbacks(exception, *args)
        give_up_callbacks.each do |callback|
          call_symbol_or_block(callback, exception, *args)
        end
      end

      def ignore_exceptions
        @ignore_exceptions ||= []
      end

      # Helper to call functions that may be passed as Symbols or Procs. If
      # a symbol, it is assumed to refer to a method that is already defined
      # on this class.
      #
      # @param [Symbol|Proc] method
      # @param [Object...] *args
      # @return [Object]
      #
      # @api private
      def call_symbol_or_block(method, *args)
        if method.is_a?(Symbol)
          send(method, *args)
        elsif method.respond_to?(:call)
          instance_exec(*args, &method)
        end
      end
    end
  end
end
