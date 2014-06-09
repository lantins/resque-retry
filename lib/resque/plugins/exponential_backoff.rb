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

      # Raised if the min/max retry-delay multiplicand configuration is invalid
      #
      # @api public
      class InvalidRetryDelayMultiplicandConfigurationException < StandardError; end

      # Constants
      #
      # @api public
      DEFAULT_RETRY_DELAY_MULTIPLICAND_MIN = 1.0
      DEFAULT_RETRY_DELAY_MULTIPLICAND_MAX = 1.0

      # Fail fast, when extended, if the "receiver" is misconfigured
      #
      # @api private
      def self.extended(receiver)
        retry_delay_multiplicand_min = \
          receiver.instance_variable_get("@retry_delay_multiplicand_min") || \
            DEFAULT_RETRY_DELAY_MULTIPLICAND_MIN
        retry_delay_multiplicand_max = \
          receiver.instance_variable_get("@retry_delay_multiplicand_max") || \
            DEFAULT_RETRY_DELAY_MULTIPLICAND_MAX
        if retry_delay_multiplicand_min > retry_delay_multiplicand_max
          raise InvalidRetryDelayMultiplicandConfigurationException.new(
            %{"@retry_delay_multiplicand_min" must be less than or equal to "@retry_delay_multiplicand_max"}
          )
        end
      end

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
        # if the values are the same don't bother generating a random number, if
        # the delta is zero, some platforms will raise an error
        if retry_delay_multiplicand_min == retry_delay_multiplicand_max
          delay_multiplicand = retry_delay_multiplicand_max
        else
          delay_multiplicand = \
            rand(retry_delay_multiplicand_min..retry_delay_multiplicand_max)
        end
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
        @retry_delay_multiplicand_min ||= DEFAULT_RETRY_DELAY_MULTIPLICAND_MIN
      end

      # @abstract
      # The maximum value (upper-bound) for the range that is is used in
      # calculating the retry-delay product
      #
      # @return [Float]
      #
      # @api public
      def retry_delay_multiplicand_max
        @retry_delay_multiplicand_max ||= DEFAULT_RETRY_DELAY_MULTIPLICAND_MAX
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
