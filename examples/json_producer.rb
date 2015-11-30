require 'bundler'

Bundler.setup

require 'poseidon'
require 'json'
require 'pry'

producer = Poseidon::Producer.new(["localhost:9092"], "json_test_producer")

srand

topics = %w(json_test_1 json_test_2)
values = %w(apple pear orange)

puts "Starting 10 producers on two topics"
puts "Press enter to continue..."

gets

threads = 10.times.map do
  Thread.new do
    150.times do
      topic = topics.sample
      payload =  { name: "#{values.sample}" }.to_json
      puts "#{topic} <- #{payload}"
      messages = 10.times.map { Poseidon::MessageToSend.new(topic, payload) }
      producer.send_messages(messages)
      sleep(rand(0.5))
    end
  end
end

threads.each(&:join)
