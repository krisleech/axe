require 'spec_helper'

module Axe
  RSpec.describe App::GzipParser do
    describe '#call' do
      it 'returns decompressed value' do
        uncompressed_text = 'this is the payload'
        compressed_text = Zlib::Deflate.deflate(uncompressed_text)
        expect(subject.call(compressed_text)).to eq uncompressed_text
      end
    end
  end
end
