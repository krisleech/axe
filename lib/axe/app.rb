require_relative 'app/consumer'
require_relative 'app/file_offset_store'
require_relative 'app/json_parser'
require_relative 'app/avro_parser'
require_relative 'app/default_parser'
require_relative 'app/runnable'

module Axe
  class App
    attr_reader :env, :logger, :exception_handler, :offset_store

    prepend Runnable

    def initialize(options = {})
      @env       = options.fetch(:env, 'production')
      @logger    = options.fetch(:logger, nil)
      @consumers = []
      @exception_handler = options.fetch(:exception_handler, default_exception_handler)
      @offset_store      = options.fetch(:offset_store, nil)
    end

    def register(options = {})
      @consumers << Consumer.new(id:      options.fetch(:id),
                                 handler: options.fetch(:handler),
                                 topic:   options.fetch(:topic),
                                 parser:  options.fetch(:parser, DefaultParser.new),
                                 env:     env,
                                 logger:  logger,
                                 exception_handler: exception_handler,
                                 offset_store:      offset_store)

      self
    end

    def consumers
      @consumers
    end

    def start
      return unless stopped?

      status(Started)

      @consumers.each do |c|
        fork do
          c.start
        end
      end

      @consumers.size.times { Process.wait }

      status(Stopped)
      self
    end

    def stop
      return unless started?
      status(Stopping)
      @consumers.each(&:stop)
      self
    end

    def test_mode!
      @env = 'test'
      self
    end

    private

    def log(message, level = :info)
      return unless logger
      logger.send(level, "[Axe] [#{Process.pid}] #{message}")
    end

    def default_exception_handler
      default_exception_handler ||= lambda { |e, consumer| consumer.send(:log, "#{e.class.name}: #{e.message}; offset: #{consumer.offset}", :error) }
    end
  end
end
