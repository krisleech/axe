require 'sequel'

module Axe
  class App
    class SQLStore
      def initialize
        @db = Sequel.sqlite

        @db.create_table :offsets do
          primary_key :id
          Integer :offset
        end

        @offsets = items = @db[:offsets]
      end

      def [](id)
        @offsets.
      end

      def []=(id, value)
        @data[id] = value
      end
    end
  end
end

