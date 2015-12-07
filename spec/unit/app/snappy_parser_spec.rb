require 'spec_helper'
require 'snappy'

module Axe
  RSpec.describe App::SnappyParser do
    describe '#call' do
      it 'returns decompressed value' do
        uncompressed_text = 'this is the payload'
        compressed_text = Snappy.deflate(uncompressed_text)
        expect(subject.call(compressed_text)).to eq uncompressed_text
      end
    end
  end
end
