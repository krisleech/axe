require 'bundler'

Bundler.setup

require 'poseidon'
require 'pry'

producer = Poseidon::Producer.new(["localhost:9092"], "some_id")

loop do
  topic = %w(test system).sample
  value = %w(apple pear orange).sample

  messages = []
  messages << Poseidon::MessageToSend.new(topic, "{ name: '#{value}' }")
  producer.send_messages(messages)
end
