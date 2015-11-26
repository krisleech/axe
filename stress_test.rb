require 'bundler'

Bundler.setup

require 'poseidon'
require 'pry'

producer = Poseidon::Producer.new(["localhost:9092"], "stress_test")

srand

topics = %w(test test2)
values = %w(apple pear orange)

threads = 10.times.map do
  Thread.new do
    150.times do
      topic = topics.sample
      puts topic
      messages = 10.times.map { Poseidon::MessageToSend.new(topic, "{ name: '#{values.sample}' }") }
      producer.send_messages(messages)
      sleep(rand(0.5))
    end
  end
end

threads.each(&:join)
