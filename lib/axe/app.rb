require_relative 'app/consumer'

module Axe
  class App
    attr_reader :env, :logger, :exception_handler

    Stopped = 'stopped'.freeze
    Started = 'started'.freeze
    Stopping = 'stopping'.freeze

    def initialize(options = {})
      @env    = options.fetch(:env, 'production')
      @logger = options.fetch(:logger, nil)
      @exception_handler = options.fetch(:exception_handler, default_exception_handler)
      @status = Stopped

      @consumers = []
    end

    def register(options = {})
      @consumers << Consumer.new(id:      options.fetch(:id),
                                 handler: options.fetch(:handler),
                                 topic:   options.fetch(:topic),
                                 env:     env,
                                 logger:  logger,
                                 exception_handler: exception_handler)

      self
    end

    def consumers
      @consumers
    end

    def start
      return unless stopped?

      @status = Started
      log "Started"

      @consumers.each do |c|
        fork do
          c.start
        end
      end

      @consumers.size.times { Process.wait }

      @status = Stopped
      log "Stopped"
      self
    end

    def stop
      return unless started?
      @status = Stopping
      log "Stopping"
      @consumers.each(&:stop)
      self
    end

    def started?
      @status == Started
    end

    def stopped?
      @status == Stopped
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
