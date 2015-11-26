require 'spec_helper'


describe Axe do
  it 'has a version number' do
    expect(Axe::VERSION).not_to be nil
  end

  # handler records all messages given to it
  class Handler
    attr_reader :messages

    def initialize
      @messages = []
    end

    def call(message)
      @messages << message
    end
  end

  it 'maps topic events to handlers' do
    app = Axe::App.new
    app.test_mode!

    topic_1 = 'axe_test_' + SecureRandom.uuid
    topic_2 = 'axe_test_' + SecureRandom.uuid

    handler_1 = Handler.new
    handler_2 = Handler.new

    app.register(id: 'handler_1',
                 handler: handler_1,
                 topic: topic_1)

    app.register(id: 'handler_2',
                 handler: handler_2,
                 topic: topic_2)

    topic_1_messages = ['message1', 'message2']
    topic_2_messages = ['message_1']

    topic_1_messages.each do |message|
      publish_event(message: message,
                    topic: topic_1)
    end

    topic_2_messages.each do |message|
      publish_event(message: message,
                    topic: topic_2)
    end

    allow(app).to receive(:fork).and_yield do |block|
      expect(handler_1.messages).to eq topic_1_messages
      expect(handler_2.messages).to eq topic_2_messages
    end

    app.start
  end

  it 'allows handler to be registered to multiple topics'

end
