module Axe
  RSpec.describe App::Consumer do
    subject(:consumer) { described_class.new(id:      id,
                                             handler: handler,
                                             topic:   topic,
                                             offset:  offset,
                                             env:     env,
                                             logger:  logger,
                                             delay:   delay,
                                             exception_handler: exception_handler)  }

    let(:id)      { 'test_id' }
    let(:handler) { double.as_null_object }
    let(:topic)   { 'test_topic' }
    let(:offset)  { 0 }
    let(:env)     { 'test' }
    let(:logger)  { double.as_null_object }
    let(:delay)   { 0 }
    let(:exception_handler) { lambda {|_| true} }

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

      describe 'exception handling' do
        describe 'when an exception occurs in the handler' do
          let(:messages) { [double(offset: 0, value: 0)] }

          before do
            allow(kafka_client).to receive(:fetch).and_return(messages)
            allow(handler).to receive(:call).and_raise('boom')
          end

          it 'retries 3 times' do
            expect(handler).to receive(:call).exactly(3).times
            consumer.start
          end

          describe 'when handler raises for a 4th time' do
            it 'calls the exception handler' do
              expect(exception_handler).to receive(:call).once
              consumer.start
            end

            it 'raise an exception with message including consumer id and offset' do
              expect(exception_handler).to receive(:call) do |ex|
                expect(ex.message).to match(/handler: #{id}/)
                expect(ex.message).to match(/offset: #{offset}/)
              end
              consumer.start
            end

            it 'stops consumer' do
              consumer.start
              expect(consumer.stopped?).to eq true
            end
          end
        end

        describe 'connection error' do
          before do
            allow(kafka_client).to receive(:fetch).and_raise('connection error')
          end

          it 'call exception handler' do
            expect(exception_handler).to receive(:call) do |ex|
              expect(ex.message).to match(/handler: #{id}/)
              expect(ex.message).to match(/offset: #{offset}/)
            end
            consumer.start
          end

          it 'stops consumer' do
            consumer.start
            expect(consumer.stopped?).to eq true
          end
        end
      end

      describe 'offsets' do
        let(:offset_store) { Hash.new }

        before { consumer.offset_store = offset_store }

        describe 'when handler does not raise an error' do
          it 'increments stored offset as messages processed' do
            messages = (0..10).to_a.map { |n| double(offset: n, value: 'a') }
            allow(kafka_client).to receive(:fetch).and_return(messages)

            consumer.start

            expect(offset_store[consumer.id]).to eq messages.last.offset
          end
        end

        describe 'when handler raises an error' do
          let(:handler) { lambda { |m| raise('error') if m == 5 } }

          it 'does not increment offset' do
            messages = (0..10).to_a.map { |n| double(offset: n, value: n) }
            allow(kafka_client).to receive(:fetch).and_return(messages)

            consumer.start

            expect(offset_store[consumer.id]).to eq 4
          end
        end

        describe 'when offset given' do
          let(:offset) { 10 }

          it 'starts from given offset' do
            skip
            # need to inject client class, not object
          end
        end
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
