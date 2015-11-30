module Axe
  RSpec.describe App do
    describe '#initialize' do
      it 'is stopped' do
        expect(subject.stopped?).to eq true
      end
    end

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

      it 'logs a starting and stopping message' do
        logger = double
        subject = described_class.new(logger: logger)
        expect(logger).to receive(:info).once.ordered.with(/Started/)
        expect(logger).to receive(:info).once.ordered.with(/Stopped/)
        subject.start
      end

    end

    describe '#stop' do
      it 'logs a stopping message' do
        logger = double.as_null_object
        subject = described_class.new(logger: logger)
        subject.register(id: 'test', topic: 'test', handler: lambda { |_| sleep(5) })
        expect(logger).to receive(:info).with(/Stopping/)
        Thread.new { subject.start }
        sleep(0.5)
        subject.stop
      end
    end
  end
end
