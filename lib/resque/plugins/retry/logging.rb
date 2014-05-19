module Resque
  module Plugins
    module Retry
      module Logging
        # Log messages through the Resque logger (DEBUG level).
        # Generally not for application logging-just for inner-workings of
        # Resque and plugins.
        #
        # @param [String] message to log
        # @param [Object] args of the resque job in context
        # @param [Object] exception that might be causing a retry
        #
        # @api private
        def log_message(message, args=nil, exception=nil)
          return unless Resque.logger

          exception_portion = exception.nil? ? '' : " [#{exception.class}/#{exception}]"
          Resque.logger.debug "resque-retry -- #{args.inspect}#{exception_portion}: #{message}"
        end
      end
    end
  end
end
