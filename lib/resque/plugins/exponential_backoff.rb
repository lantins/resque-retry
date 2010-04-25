module Resque
  module Plugins
    module ExponentialBackoff
      include Resque::Plugins::Retry

      def retry_limit
        @retry_limit ||= backoff_strategy.length
      end

      # get retry delay
      def seconds_until_retry
        backoff_strategy[retry_attempt] || backoff_strategy.last
      end

      # define backoff strategy
      def backoff_strategy
        @backoff_strategy ||= [0, 60, 600, 3600, 10_800, 21_600]
      end
    end
  end
end