module Resque
  module Plugins

    ##
    # If you want your job to retry on failure using a varying delay, simply
    # extend your module/class with this module:
    #
    #   class DeliverSMS
    #     extend Resque::Plugins::ExponentialBackoff
    #
    #     def self.perform(mo_id, mobile_number, message)
    #       heavy_lifting
    #     end
    #   end
    #
    # Easily do something custom:
    #
    #   class DeliverSMS
    #     extend Resque::Plugins::ExponentialBackoff
    #
    #     @retry_limit = 4
    #
    #     # retry delay in seconds; [0] => 1st retry, [1] => 2nd..4th retry.
    #     @backoff_strategy = [0, 60]
    #
    #     # used to build redis key, for counting job attempts.
    #     def self.identifier(mo_id, mobile_number, message)
    #       "#{mobile_number}:#{mo_id}"
    #     end
    #
    #     self.perform(mo_id, mobile_number, message)
    #       heavy_lifting
    #     end
    #   end
    #
    module ExponentialBackoff
      include Resque::Plugins::Retry

      ##
      # Defaults to the number of delays in the backoff strategy.
      #
      # @return [Number] maximum number of retries
      def retry_limit
        @retry_limit ||= backoff_strategy.length
      end

      ##
      # Selects the delay from the backoff strategy.
      #
      # @return [Number] seconds to delay until the next retry.
      def retry_delay
        backoff_strategy[retry_attempt] || backoff_strategy.last
      end

      ##
      # @abstract
      # The backoff strategy is used to vary the delay between retry attempts.
      # 
      # @return [Array] array of delays. index = retry attempt
      def backoff_strategy
        @backoff_strategy ||= [0, 60, 600, 3600, 10_800, 21_600]
      end
    end

  end
end