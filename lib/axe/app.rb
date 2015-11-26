require_relative 'app/consumer'

module Axe
  class App
    def initialize
      @consumers = []
    end

    def register(options = {})
      @consumers << Consumer.new(handler: options.fetch(:handler),
                                 topic:   options.fetch(:topic))
    end

    def consumers
      @consumers
    end

    def start
      @consumers.each(&:start)
    end

    def stop
      @consumers.each(&:stop)
    end
  end
end
