require 'snappy'

# Parser to decompress Snappy compressed payloads
# https://google.github.io/snappy/

module Axe
  class App
    class SnappyParser
      def call(payload)
        Snappy.inflate(payload)
      end
    end
  end
end
