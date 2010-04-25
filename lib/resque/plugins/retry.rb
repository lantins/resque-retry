module Resque
  module Plugins
    
    ##
    # If you want your job to retry on failure, simply extend your module/class
    # with this module:
    #
    #   class DeliverWebHook
    #     extend Resque::Plugins::Retry # allows 1 retry by default.
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
    #
    #     @retry_limit = 8          # default: 1
    #     @seconds_until_retry = 60 # default: 0
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
      ##
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
        args.join('-')
      end

      ##
      # Builds the redis key to be used for keeping state of the job
      # attempts.
      #
      # @return [String] redis key
      def key(*args)
        ['resque-retry', name, identifier(*args)].compact.join(":")
      end

      ##
      # Maximum number of retrys we can attempt to successfully perform the job.
      # A retry limit of 0 or below will retry forever.
      #
      # @return [Fixnum]
      def retry_limit
        @retry_limit ||= 1
      end

      ##
      # Number of retry attempts used to try and perform the job.
      #
      # The real value is kept in Redis, it is accessed and incremented using
      # a before_perform hook.
      #
      # @return [Fixnum] number of attempts
      def retry_attempt
        @retry_attempt ||= 0
      end

      ##
      # @abstract
      # Number of seconds to delay until the job is retried.
      # 
      # @return [Number] number of seconds to delay
      def seconds_until_retry
        @seconds_until_retry ||= 0
      end

      ##
      # @abstract
      # Modify the arguments used to retry the job. Use this to do something
      # other than try the exact same job again.
      #
      # @return [Array] new job arguments
      def args_for_retry(*args)
        args
      end

      ##
      # Convenience method to test whether you may retry on a given exception.
      #
      # @return [Boolean]
      def retry_exception?(exception)
        return true if retry_exceptions.nil?
        !! retry_exceptions.any? { |ex| ex >= exception }
      end

      ##
      # @abstract
      # Controls what exceptions may be retried.
      #
      # Default: `nil` - this will retry all exceptions.
      # 
      # @return [Array, nil]
      def retry_exceptions
        @retry_exceptions ||= nil
      end

      ##
      # Test if the retry criteria is valid.
      #
      # @param [Exception] exception
      # @param [Array] args job arguments
      # @return [Boolean]
      def retry_criteria_valid?(exception, *args)
        # FIXME: let people extend retry criteria, give them a chance to say no.
        if retry_limit > 0
          return false if retry_attempt >= retry_limit
        end
        retry_exception?(exception.class)
      end

      ##
      # Will retry the job.
      #
      # n.b. If your not using the resque-scheduler plugin your job will block
      # your worker, while it sleeps for `seconds_until_retry`.
      def try_again(*args)
        if Resque.respond_to?(:enqueue_in) && seconds_until_retry > 0
          Resque.enqueue_in(seconds_until_retry, self, *args_for_retry(*args))
        else
          sleep(seconds_until_retry) if seconds_until_retry > 0
          Resque.enqueue(self, *args_for_retry(*args))
        end
      end

      ##
      # Resque before_perform hook.
      #
      # Increments and sets the `@retry_attempt` count.
      def before_perform_retry(*args)
        Resque.redis.setnx(key(*args), -1)             # default to -1 if not set.
        @retry_attempt = Resque.redis.incr(key(*args)) # increment by 1.
      end

      ##
      # Resque after_perform hook.
      #
      # Deletes retry attempt count from Redis.
      def after_perform_retry(*args)
        Resque.redis.del(key(*args))
      end

      ##
      # Resque on_failure hook.
      #
      # Checks if our retry criteria is valid, if it is we try again.
      # Otherwise the retry attempt count is deleted from Redis.
      def on_failure_retry(exception, *args)
        if retry_criteria_valid?(exception, *args)
          try_again(*args)
        else
          delete_retry_redis_key(*args)
        end
      end
    end

  end
end