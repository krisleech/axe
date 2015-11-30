require 'avro'

module Axe
  class App
    class AvroParser
      def call(payload)
        Avro::DataFile::Reader.new(StringIO.new(payload), Avro::IO::DatumReader.new).to_a
      end
    end
  end
end
