module Resque
  module Plugins
    module Retry
      module Hooks
        # Returns a sorted list of hook methods, according to the hook prefix.
        #
        # @param hook_prefix [String]
        #
        # @returns [Array<Symbol>]
        #
        # @api private
        def get_hook_names(hook_prefix)
          hooks = self.methods.select do |method|
            method.to_s.start_with?(hook_prefix)
          end
          hooks.sort
        end

        # Returns a list of hooks to be run when the job has failed but is
        # trying again.
        #
        # @api private
        def try_again_hooks
          get_hook_names("on_try_again")
        end


        # Returns a list of hooks to be run when the job has failed and is not
        # retrying.
        #
        # @api private
        def give_up_hooks
          get_hook_names("on_give_up")
        end

        # Runs the hooks for when the job has failed but is trying again.
        #
        # @param exception [Exception]
        # @param *job_args [Object...]
        #
        # @api private
        def run_try_again_hooks(exception, *job_args)
          try_again_hooks.each do |hook|
            self.__send__(hook, exception, *job_args)
          end
        end

        # Runs the hooks for when the job has failed and is not trying again.
        #
        # @param exception [Exception]
        # @param *job_args [Object...]
        #
        # @api private
        def run_give_up_hooks(exception, *job_args)
          give_up_hooks.each do |hook|
            self.__send__(hook, exception, *job_args)
          end
        end
      end
    end
  end
end
