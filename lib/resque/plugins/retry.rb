module Resque
  module Plugins

    module Retry
      # nil = retry forever
      def retry_limit
        @retry_limit ||= 1
      end

      def retry_attempt
        @retry_attempt ||= 1
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
      def retry_criteria_valid?(exception = nil, *args)
        return false if attempts >= retry_limit
        retry_exception?(exception.class) if exception
      end

      def seconds_until_retry
        @seconds_until_retry ||= 0
      end

      def args_for_retry(*args)
        args
      end

      def try_again(*args)
        if Resque.respond_to?(:enqueue_in) && seconds_until_retry > 0
          Resque.enqueue_in(seconds_until_retry, self, *args_for_try_again(*args))
        else
          sleep(seconds_until_retry) if seconds_until_retry > 0
          Resque.enqueue(self, *args_for_retry(*args))
        end
      end

      def on_failure_retry_on_exception(exception, *args)
        try_again(*args) if retry_criteria_valid?(exception)
      end
    end

  end
end