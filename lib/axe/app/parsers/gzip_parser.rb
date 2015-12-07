# Uncompress a GZiped payload
#
module Axe
  class App
    class GzipParser
      def call(payload)
        Zlib::Inflate.inflate(payload)
      end
    end
  end
end
