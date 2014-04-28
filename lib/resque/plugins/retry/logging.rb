module Resque
  module Plugins
    module Retry
      module Logging
        # Log messages through the Resque logger.  Generally not for appication
        # logging-just for inner-workings of Resque and plugins.
        #
        # message:: message to log
        # args:: args of the resque job in context
        # exception:: the exception that might be causing a retry
        #
        # @api private
        def log_message(message,args=nil,exception=nil)
          if Resque.logger
            exception_portion = exception.nil? ? '' : " [#{exception.class}/#{exception}]"
            Resque.logger.info "#{args.inspect}#{exception_portion}: #{message}"
          end
        end
      end
    end
  end
end
