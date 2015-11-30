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
        File.open(filename(id), File::RDWR|File::CREAT, 0644) do |file|
          file.flock(File::LOCK_NB|File::LOCK_EX)
          file.write(value.to_s + "\n")
        end
      end

      private

      def filename(id)
        File.join(@path, id.to_s + '.offset')
      end
    end
  end
end
