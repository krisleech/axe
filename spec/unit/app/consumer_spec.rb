module Axe
  RSpec.describe App::Consumer do
    subject(:consumer) { described_class.new(id:      id,
                                             handler: handler,
                                             topic:   topic,
                                             offset:  offset,
                                             env:     env,
                                             logger:  logger,
                                             delay:   delay,
                                             parser:  parser,
                                             retries: retries,
                                             exception_handler: exception_handler,
                                             from_parent: from_parent)  }

    let(:id)      { 'test_id' }
    let(:handler) { double('handler').as_null_object }
    let(:topic)   { 'test_topic' }
    let(:offset)  { 0 }
    let(:env)     { 'test' }
    let(:logger)  { double('logger').as_null_object }
    let(:delay)   { 0 }
    let(:parser)  { lambda { |msg| msg } }
    let(:retries) { 1 }
    let(:exception_handler) { lambda {|e,_| puts(e.message)} }
    let(:from_parent) { double('from_parent', gets: nil) }

    describe '#initalize' do
      it 'is stopped' do
        expect(subject.stopped?).to eq true
      end
    end

    describe '#start' do
      let(:kafka_client) { double('kafka_client', fetch: []) }

      before { consumer.kafka_client = kafka_client }

      it 'fetches messages from Kafka for the topic' do
        expect(kafka_client).to receive(:fetch).and_return([])
        consumer.start
      end

      it 'calls handler with each message' do
        value = 'hello, world'
        message = double('message', offset: 1, value: value)
        allow(kafka_client).to receive(:fetch).and_return([message])
        expect(handler).to receive(:call).with(value)
        consumer.start
      end

      describe 'parsing message' do
        let(:messages) { [double('message', offset: 0, value: 'foobar')] }

        before do
          allow(kafka_client).to receive(:fetch).and_return(messages)
        end

        it 'passes message to parser' do
          expect(parser).to receive(:call).with(messages[0].value)
          consumer.start
        end

        describe 'given an array of parsers' do
          let(:parser) { [parser_1, parser_2] }
          let(:parser_1) { double }
          let(:parser_2) { double }

          it 'chains parsers together' do
            different_value = 'different value'
            expect(parser_1).to receive(:call).with(messages[0].value).and_return(different_value)
            expect(parser_2).to receive(:call).with(different_value)
            consumer.start
          end
        end
      end

      describe 'exception handling' do
        describe 'when an exception occurs in the handler' do
          let(:retries)  { 3 }
          let(:messages) { [double('message', offset: 0, value: 0)] }

          before do
            allow(kafka_client).to receive(:fetch).and_return(messages)
            allow(handler).to receive(:call).and_raise('boom')
          end

          it 'retries 3 times' do
            expect(handler).to receive(:call).exactly(retries).times
            consumer.start
          end

          describe 'when handler raises for a 4th time' do
            it 'calls the exception handler' do
              expect(exception_handler).to receive(:call).once
              consumer.start
            end

            it 'raise an exception passing exception and consumer' do
              expect(exception_handler).to receive(:call).with(kind_of(StandardError),
                                                               kind_of(described_class))
              consumer.start
            end

            it 'stops consumer' do
              consumer.start
              expect(consumer.stopped?).to eq true
            end
          end
        end

        describe 'when Kafka client raises a connection error' do
          before do
            allow(kafka_client).to receive(:fetch).and_raise('connection error')
          end

          it 'call exception handler' do
            expect(exception_handler).to receive(:call).with(kind_of(StandardError),
                                                             kind_of(described_class))
            consumer.start
          end

          it 'stops consumer' do
            consumer.start
            expect(consumer.stopped?).to eq true
          end
        end

        describe 'when Kafaka client raise Poseidon::Errors::UnknownTopicOrPartition' do
          before do
            allow(kafka_client).to receive(:fetch).and_raise(Poseidon::Errors::UnknownTopicOrPartition)
          end

          let(:topic) { 'does not exist' }

          it 'logs the exception' do
            expect(logger).to receive(:warn).with(/Unknown Topic: #{topic}/).at_least(:once)
            Thread.new { consumer.start }
            sleep(2)
            consumer.stop
          end

          it 'tries to fetch messages again' do
            expect(kafka_client).to receive(:fetch).at_least(:twice)
            Thread.new { consumer.start }
            sleep(2)
            consumer.stop
          end
        end
      end

      describe 'offsets' do
        let(:offset_store) { Hash.new }

        before { consumer.offset_store = offset_store }

        describe 'when handler does not raise an error' do
          it 'increments stored offset as messages processed' do
            messages = (0..10).to_a.map { |n| double('message', offset: n, value: 'a') }
            allow(kafka_client).to receive(:fetch).and_return(messages)

            consumer.start

            expect(offset_store[consumer.id]).to eq messages.last.offset
          end
        end

        describe 'when handler raises an error' do
          let(:handler) { lambda { |m| raise('error') if m == 5 } }

          it 'does not increment offset' do
            messages = (0..10).to_a.map { |n| double('message', offset: n, value: n) }
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
    end

    describe '#stop' do
      let(:handler) { lambda { |_| sleep(0.5) } }

      it 'stops message processing' do
        consumer.kafka_client = double('kafka_client', fetch: Array.new(100) { |n| double(offset: n, value: 'a') })

        Thread.new { consumer.start }

        sleep(1)
        consumer.stop

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
