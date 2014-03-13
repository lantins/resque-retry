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

        # If we are adding some randomness to the delay value, multiply the value by some float between
        # [1.0, random_quotient_range]
        if add_random_quotient?
          delay = (delay * (Random.rand(random_quotient_range.to_i * 10) + 10) / 10.0).to_i
        end

        delay
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

      # @abstract Whether or not to add a random quotient when calculating exponential backoff. This is useful if you
      # have multiple jobs at once that all fail at the same time (e.g., network is down) and you don't want them to all
      # be retried at the same time.
      # @return [Boolean] Whether or not to add a random quotient
      def add_random_quotient?
        @add_random_quotient
      end

      # @abstract The random quotient variability. When set to x, it means that the delay value chosen at any given
      # time will be delay_value * Random([1.0, x]). So if you set this to 3.0, then your delay value will be multiplied
      # by a random number between 1.0 and 3.0.
      # @return [Float] The maximum range to be used to multiply values when adding a random quotient.
      def random_quotient_range
        @random_quotient_range ||= 3.0
      end
    end
  end
end
