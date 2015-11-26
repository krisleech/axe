require_relative 'app/consumer'

module Axe
  class App
    attr_reader :env, :logger

    def initialize(options = {})
      @env    = options.fetch(:env, 'production')
      @logger = options.fetch(:logger, nil)

      @consumers = []
    end

    def register(options = {})
      @consumers << Consumer.new(id:      options.fetch(:id),
                                 handler: options.fetch(:handler),
                                 topic:   options.fetch(:topic),
                                 env:     env,
                                 logger:  logger)

      self
    end

    def consumers
      @consumers
    end

    def start
      log "Started"

      @consumers.each do |c|
        fork do
          c.start
        end
      end

      @consumers.size.times { Process.wait }

      log "Stopped"
      self
    end

    def stop
      log "Stopping"
      @consumers.each(&:stop)
      self
    end

    def test_mode!
      @env = 'test'
      self
    end

    private

    def log(message, level = :info)
      logger.send(level, "[Axe] [#{Process.pid}] #{message}")
    end
  end
end
