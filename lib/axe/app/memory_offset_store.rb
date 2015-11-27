module Axe
  class App
    class MemoryOffsetStore
      def initialize
        @data = {}
      end

      def [](id)
        @data[id]
      end

      def []=(id, value)
        @data[id] = value
      end
    end
  end
end
