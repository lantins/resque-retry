module Resque
  module Plugins
    module Retry
      module Logging
        def format_message(message,args=nil,exception=nil)
          exception_portion = exception.nil? ? '' : " [#{exception.class}/#{exception}]"
          message = "#{args.inspect}#{exception_portion}: #{message}"
        end
      end
    end
  end
end
