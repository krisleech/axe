$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'axe'

require 'poseidon'

require 'pry'

class TestPublisher
  def publish(options)
    client.send_messages([Poseidon::MessageToSend.new(options.fetch(:topic),
                                                      options.fetch(:message))])
  rescue Poseidon::Errors::UnableToFetchMetadata
    raise 'Test producer can not connect to Kafka. Ensure Zookeeper and Kafka are started.'
  end

  def client
    @client ||= Poseidon::Producer.new(["localhost:9092"], 'test_producer')
  end
end

def test_producer
  @test_producer ||= TestPublisher.new
end

def publish_event(options)
  test_producer.publish(options)
end

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end
