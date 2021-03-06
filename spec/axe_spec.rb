require 'spec_helper'


describe Axe, type: 'acceptance' do

  # Handler writes messages to given file
  #
  # Since we handlers are forked and executed in a different process we cannot
  # access their state from the parent process.
  #
  # Instead we use the file system as a globally accessable storage.
  #
  class Handler
    def initialize(filename)
      @filename = filename
      File.delete(filename) if File.exists?(filename)
    end

    def call(message)
      File.open(@filename, 'a') do |file|
        file.write(message)
      end
    end
  end

  it 'maps topic events to handlers' do
    app = Axe::App.new(logger: Logger.new('test.log'),
                       exception_handler: lambda { |e,c| raise e })
    app.test_mode!

    topics = [1,2,3,4,5].map do |num|
      id = SecureRandom.uuid
      filename =  File.join(Dir.tmpdir, "#{id}.axe.test")
      {
        id: id,
        name: "axe_test_#{num}",
        filename: filename,
        messages: Array.new(5) { SecureRandom.uuid },
        handler: Handler.new(filename)
      }
    end

    topics.each do |topic|
      # register the handler to the topic
      app.register(id: topic[:id],
                   handler: topic[:handler],
                   topic: topic[:name])

      # publish messages to the topic
      topic[:messages].each do |message|
        publish_event(message: message, topic: topic[:name])
      end
    end

    app.start

    topics.each do |topic|
      file = File.read(topic[:filename])
      expect(file).to include topic[:messages].join('')
    end
  end
end
