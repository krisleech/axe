module Axe
  RSpec.describe App do
    describe '#register' do
      it 'registers a handler to a topic' do
        app = described_class.new

        handler = Object.new
        topic = 'a_topic'

        app.register(id: 'test_id',
                     handler: handler,
                     topic: topic)

        consumer = app.consumers.first

        expect(consumer.handler).to eq handler
        expect(consumer.topic).to eq topic
      end
    end

    describe '#start' do
      it 'creates a process per handler'
    end
  end
end
