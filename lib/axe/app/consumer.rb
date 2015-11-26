module Axe
  class App
    class Consumer
      attr_reader :handler, :topic

      def initialize(options)
        @handler = options.fetch(:handler)
        @topic   = options.fetch(:topic)
        @kafka_client = options.fetch(:kafka_client, nil)
      end

      def start
        kafka_client.fetch.each do |message|
          handler.call(message.value)
        end
      end

      def stop

      end

      private

      def kafka_client
        @kafka_client ||= Poseidon::PartitionConsumer.new("my_test_consumer", "localhost", 9092, @topic, 0, :earliest_offset)
      end
    end
  end
end
