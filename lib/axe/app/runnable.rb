# State machine mixin for making a object runnable.
#
module Axe
  class App
    module Runnable
      Stopped  = 'stopped'.freeze
      Started  = 'started'.freeze
      Stopping = 'stopping'.freeze

      def initialize(*args)
        @status = Stopped
        super
      end

      # Returns true when consumer has been started
      #
      def started?
        @status == Started
      end

      # Returns true when the consumer is in the process of stopping
      #
      def stopping?
        @status == Stopping
      end

      # Returns true when the consumer is stopped
      #
      def stopped?
        @status == Stopped
      end

      private

      # sets a new status and logs change
      #
      def status(new_status)
        @status = new_status
        log @status.to_s.capitalize
      end
    end
  end
end
