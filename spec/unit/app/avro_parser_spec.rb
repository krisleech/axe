require 'spec_helper'

module Axe
  RSpec.describe App::AvroParser do
    describe '#call' do
      describe 'given valid Avro' do
        it 'returns a type cast Ruby object' do
          expect(subject.call(build_avro)).to eq([{"username"=>"john", "age"=>25, "verified"=>true}])
        end
      end



      describe 'given invalid Avro' do
        it 'raises an error' do
          json = 'not json'
          expect { subject.call(json) }.to raise_error
        end
      end
    end

    SCHEMA = <<-JSON
{ "type": "record",
  "name": "User",
  "fields" : [
    {"name": "username", "type": "string"},
    {"name": "age", "type": "int"},
    {"name": "verified", "type": "boolean", "default": "false"}
  ]}
    JSON

    def build_avro
      schema = Avro::Schema.parse(SCHEMA)
      writer = Avro::IO::DatumWriter.new(schema)
      result = StringIO.new
      dw = Avro::DataFile::Writer.new(result, writer, schema)
      dw << {"username" => "john", "age" => 25, "verified" => true}
      dw.close

      result.string
    end
  end
end
