module Axe
  class App
    class FileOffsetStore
      def initialize(options)
        @path = options.fetch(:path).to_s
        raise "path does exist: #{@path}" unless Dir.exists?(@path)
      end

      def [](id)
        File.open(filename(id), File::RDWR) do |file|
          file.flock(File::LOCK_EX)
          file.read.to_i
        end
      rescue Errno::ENOENT
        nil
      end

      def []=(id, value)
        raise ArgumentError, "given offset is not a number: #{value.class.name}" unless value.is_a?(Integer)
        File.open(filename(id), File::RDWR|File::CREAT, 0644) do |file|
          file.flock(File::LOCK_NB|File::LOCK_EX)
          file.write(value.to_s + "\n")
        end
      end

      private

      def filename(id)
        File.join(@path, sanatize_filename(id) + '.offset')
      end

      # replace characters which cannot be in a filename
      #
      def sanatize_filename(id)
        id.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')
      end
    end
  end
end
