module Axe
  class App
    class FileOffsetStore
      def initialize(options)
        @path = options.fetch(:path).to_s
        raise "path does exist: #{@path}" unless Dir.exists?(@path)
      end

      # returns offset for given id
      #
      # checks in-memory cache first, then disk cache, if no hit found then nil
      # is returned
      #
      # @return <Integer, nil>
      #
      def [](id)
        cache[:offsets][id] ||= begin
                                  begin
                                    File.open(filename(id), File::RDWR) do |file|
                                      file.flock(File::LOCK_EX)
                                      file.read.to_i
                                    end
                                  rescue Errno::ENOENT
                                    nil
                                  end
                                end
      end

      # sets offset for given id
      #
      # @return <self>
      #
      def []=(id, offset)
        raise ArgumentError, "given offset is not a number: #{offset.class.name}" unless offset.is_a?(Integer)
        File.open(filename(id), File::RDWR|File::CREAT, 0644) do |file|
          file.flock(File::LOCK_NB|File::LOCK_EX)
          file.write(offset.to_s + "\n")
        end

        cache[:offsets][id] = offset
        self
      end

      private

      # An in-memory namepsaced cache for key/value pairs
      #
      # @example
      #   cache[:namespace][:key] = value
      #
      def cache
        @cache ||= Hash.new { |h,k| h[k] = {} }
      end

      # returns a filename for the given id
      #
      # @return <String>
      #
      def filename(id)
        cache[:filenames][id] ||= File.join(@path, sanatize_filename(id) + '.offset')
      end

      # replaces characters which cannot be in a filename
      #
      # @return <String>
      #
      def sanatize_filename(id)
        id.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')
      end
    end
  end
end
