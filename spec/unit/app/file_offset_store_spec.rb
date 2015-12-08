require 'spec_helper'

module Axe
  RSpec.describe App::FileOffsetStore do
    subject { described_class.new(path: Dir.tmpdir) }

    describe '#[]' do
      describe 'when no offset stored' do
        it 'returns nil' do
          expect(subject['made up key']).to eq nil
        end
      end
    end

    describe '#[]=' do
      it 'stores the offset keyed to the id' do
        key = 'key'
        value = 10
        subject[key] = value
        expect(subject[key]).to eq 10
      end

      describe 'given a non-number offset' do
        it 'raises an error' do
          expect{subject['key'] = '1'}.to raise_error(ArgumentError)
        end
      end

      describe 'when id contains forward slashes' do
        it 'stores the offset keyed to the id' do
          key = 'namespaced/key'
          value = 10
          subject[key] = value
          expect(subject[key]).to eq value
        end
      end
    end
  end
end
