require 'bundler'

Bundler.setup

require 'poseidon'
require 'pry'

producer = Poseidon::Producer.new(["localhost:9092"], "string_test_producer")

srand

topics = %w(basic_test)
words = File.open('/usr/share/dict/words', 'r') { |f| f.read }.split("\n")

puts "Starting 10 producers on two topics"
puts "Press enter to continue..."

gets

threads = 10.times.map do
  Thread.new do
    150.times do
      topic = topics.sample
      payload =  words.sample
      puts "#{topic} <- #{payload}"
      messages = 10.times.map { Poseidon::MessageToSend.new(topic, payload) }
      producer.send_messages(messages)
      sleep(rand(0.5))
    end
  end
end

threads.each(&:join)
