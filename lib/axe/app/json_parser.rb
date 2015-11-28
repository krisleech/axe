require 'json'

module Axe
  class App
    class JSONParser
      def call(payload)
        JSON.parse(payload)
      end
    end
  end
end
