module Axe
  RSpec.describe App::Consumer do
    subject(:consumer) { described_class.new(id:      id,
                                             handler: handler,
                                             topic:   topic,
                                             env:     env,
                                             logger:  logger,
                                             delay:   delay)  }

    let(:id)      { 'test_id' }
    let(:handler) { double }
    let(:topic)   { 'test_topic' }
    let(:env)     { 'test' }
    let(:logger)  { double.as_null_object }
    let(:delay)   { 0 }

    describe '#initalize' do
      it 'is stopped' do
        expect(subject.stopped?).to eq true
      end
    end

    describe '#start' do
      let(:kafka_client) { double(fetch: []) }

      before { consumer.kafka_client = kafka_client }

      it 'fetches messages from Kafka for the topic' do
        expect(kafka_client).to receive(:fetch).and_return([])
        consumer.start
      end

      it 'calls handler with each message' do
        value = 'hello, world'
        message = double(offset: 1, value: value)
        allow(kafka_client).to receive(:fetch).and_return([message])
        expect(handler).to receive(:call).with(value)
        consumer.start
      end

      it 'writes a started message to the log' do
        expect(logger).to receive(:info).with(/Started/)
        consumer.start
      end

      it 'handles unknown topic' # Poseidon::Errors::UnknownTopicOrPartition
    end

    describe '#stop' do
      let(:handler) { lambda { |_| sleep(0.5) } }

      it 'stops message processing' do
        consumer.kafka_client = double(fetch: Array.new(100) { |n| double(offset: n, value: 'a') })


        # does not work on MRI
        t = Thread.new do
          consumer.start
        end

        sleep(1)
        consumer.stop
        sleep(3)

        expect(consumer.offset).to be < 4
      end
    end

    %w(id handler topic env logger delay).each do |method|
      describe "##{method}" do
        it "returns configured #{method}" do
          expect(consumer.send(method)).to eq(send(method))
        end
      end
    end
  end
end
