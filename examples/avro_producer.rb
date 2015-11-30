require 'bundler'

Bundler.setup

require 'poseidon'
require 'avro'
require 'pry'

producer = Poseidon::Producer.new(["localhost:9092"], "avro_test_producer")

srand

topics = %w(avro_test_1 avro_test_2)

moons = [
  { "name" => 'Pan', "discovered" => 1990 },
  { "name" => 'Daphnis', "discovered" => 2005 },
  { "name" => 'Atlasi', "discovered" => 1980 },
  { "name" => 'Prometheus', "discovered" => 1980 },
  { "name" => 'Pandora', "discovered" => 1980 },
  { "name" => 'Epimetheus', "discovered" => 1977 }
]

SCHEMA = { "type": "record",
           "name": "Moon",
           "fields": [
             {"name": "name", "type": "string"},
             {"name": "discovered", "type": "int"} 
           ]
}.to_json

schema = Avro::Schema.parse(SCHEMA)
writer = Avro::IO::DatumWriter.new(schema)

puts "Starting 1 producer on two topics"
puts "Press enter to continue..."

gets

150.times do
  topic = topics.sample

  result = StringIO.new
  dw = Avro::DataFile::Writer.new(result, writer, schema)
  dw << moons.sample
  dw.close
  payload = result.string

  messages = [Poseidon::MessageToSend.new(topic, payload)]

  puts "#{topic} <- #{payload.inspect}"

  producer.send_messages(messages)
  sleep(rand(0.5))
end
