require 'spec_helper'

module Axe
  RSpec.describe App::JSONParser do
    describe '#call' do
      describe 'given valid JSON' do
        it 'returns a Ruby object' do
          hash = { "name" => 'Kris' }
          json = hash.to_json
          expect(subject.call(json)).to eq hash
        end
      end

      describe 'given invalid JSON' do
        it 'raises an error' do
          json = 'not json'
          expect { subject.call(json) }.to raise_error
        end
      end
    end
  end
end
