module Resque
  module Plugins

    # If you want your job to retry on failure using a varying delay, simply
    # extend your module/class with this module:
    #
    #   class DeliverSMS
    #     extend Resque::Plugins::ExponentialBackoff
    #     @queue = :mt_messages
    #
    #     def self.perform(mt_id, mobile_number, message)
    #       heavy_lifting
    #     end
    #   end
    #
    # Easily do something custom:
    #
    #   class DeliverSMS
    #     extend Resque::Plugins::ExponentialBackoff
    #     @queue = :mt_messages
    #
    #     @retry_limit = 4
    #
    #     # retry delay in seconds; [0] => 1st retry, [1] => 2nd..4th retry.
    #     @backoff_strategy = [0, 60]
    #
    #     # used to build redis key, for counting job attempts.
    #     def self.retry_identifier(mt_id, mobile_number, message)
    #       "#{mobile_number}:#{mt_id}"
    #     end
    #
    #     self.perform(mt_id, mobile_number, message)
    #       heavy_lifting
    #     end
    #   end
    #
    module ExponentialBackoff
      include Resque::Plugins::Retry

      # Defaults to the number of delays in the backoff strategy
      #
      # @return [Number] maximum number of retries
      #
      # @api private
      def retry_limit
        @retry_limit ||= backoff_strategy.length
      end

      # Selects the delay from the backoff strategy
      #
      # @return [Number] seconds to delay until the next retry.
      #
      # @api private
      def retry_delay
        delay = backoff_strategy[retry_attempt] || backoff_strategy.last
        delay_multiplicand = \
          rand(retry_delay_multiplicand_min..retry_delay_multiplicand_max)
        (delay * delay_multiplicand).to_i
      end

      # @abstract
      # The minimum value (lower-bound) for the range that is is used in
      # calculating the retry-delay product
      #
      # @return [Float]
      #
      # @api public
      def retry_delay_multiplicand_min
        @retry_delay_multiplicand_min ||= 1.0
      end

      # @abstract
      # The maximum value (upper-bound) for the range that is is used in
      # calculating the retry-delay product
      #
      # @return [Float]
      #
      # @api public
      def retry_delay_multiplicand_max
        @retry_delay_multiplicand_max ||= 1.0
      end

      # @abstract
      # The backoff strategy is used to vary the delay between retry attempts
      # 
      # @return [Array] array of delays. index = retry attempt
      #
      # @api public
      def backoff_strategy
        @backoff_strategy ||= [0, 60, 600, 3600, 10_800, 21_600]
      end
    end

  end
end
