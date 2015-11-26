module Axe
  RSpec.describe App::Consumer do
    describe '#start' do
      it 'fetches messages from Kafka for the topic' do
        kafka_client = double

        consumer = described_class.new(handler: Object.new, topic: 'a_topic',
                                       kafka_client: kafka_client)

        expect(kafka_client).to receive(:fetch).and_return([])

        consumer.start
      end

      it 'calls handler with each message' do
        kafka_client = double

        handler = double

        consumer = described_class.new(handler: handler, topic: 'a_topic',
                                       kafka_client: kafka_client)

        value = 'hello, world'
        message = double(value: value)
        allow(kafka_client).to receive(:fetch).and_return([message])

        expect(handler).to receive(:call).with(value)
        consumer.start
      end

      it 'writes a started message to the log'

      it 'handles unknown topic' # Poseidon::Errors::UnknownTopicOrPartition
    end

    describe '#handler' do
      it 'returns configured handler' do
        handler = Object.new
        topic = 'a_topic'

        consumer = described_class.new(handler: handler,
                                       topic: topic)

        expect(consumer.handler).to eq(handler)
      end
    end

    describe '#topic' do
      it 'returns configured topic' do
        handler = Object.new
        topic = 'a_topic'

        consumer = described_class.new(handler: handler,
                                       topic: topic)

        expect(consumer.topic).to eq(topic)
      end
    end
  end
end
