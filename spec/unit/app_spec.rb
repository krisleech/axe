module Axe
  RSpec.describe App do
    describe '#register' do
      it 'registers a handler to a topic' do
        app = described_class.new

        handler = Object.new
        topic = 'a_topic'

        app.register(handler: handler,
                     topic: topic)

        consumer = app.consumers.first

        expect(consumer.handler).to eq handler
        expect(consumer.topic).to eq topic
      end
    end

    describe '#start' do
      it 'creates a process per handler'

      it 'maps Kafka messages to handler by topic' do
        app = described_class.new
        # app.register
      end
    end
  end
end
