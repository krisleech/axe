require_relative 'app/consumer'
require_relative 'app/offset_stores/all'
require_relative 'app/parsers/all'
require_relative 'shared/runnable'

# Application
#
# * Registration of handlers to topics (Consumer)
# * Preforking of processes, one per consumer
# * Communication between parent and child process via Pipes

module Axe
  class App
    attr_reader :env, :logger, :exception_handler, :offset_store

    prepend Runnable

    DuplicateConsumerId = Class.new(StandardError)

    def initialize(options = {})
      @env       = options.fetch(:env, 'production')
      @logger    = options.fetch(:logger, nil)
      @consumers = []
      @exception_handler = options.fetch(:exception_handler, default_exception_handler)
      @offset_store      = options.fetch(:offset_store, nil)
      @pipes = {}
      set_procname("axe [master]")
    end

    def register(options = {})
      validate_options(options)

      from_parent, to_child = IO.pipe

      @pipes[options.fetch(:id)] = { to_child: to_child }

      @consumers << Consumer.new(id:      options.fetch(:id),
                                 handler: options.fetch(:handler),
                                 topic:   options.fetch(:topic),
                                 parser:  options.fetch(:parser, DefaultParser.new),
                                 env:     env,
                                 logger:  logger,
                                 exception_handler: exception_handler,
                                 offset_store:      offset_store,
                                 from_parent: from_parent)

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
          set_procname("axe [#{c.id}]")
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
      send_to_all_forks('stop')
      self
    end

    def test_mode!
      @env = 'test'
      self
    end

    private

    # Sends a message via a pipe to all child processes
    #
    def send_to_all_forks(message)
      log "Sending #{message} to all children", :debug
      @pipes.each do |id, pipes|
        log "Sending #{message} to #{id}", :debug
        pipes[:to_child].puts "Stop"
      end

    def set_procname(name)
      Process.setproctitle(name)
    end

    def validate_options(options)
      id = options.fetch(:id)
      raise(DuplicateConsumerId, "Consumer with id #{id} has already been registered") if @consumers.map(&:id).include?(id)
    end

    def log(message, level = :info)
      return unless logger
      logger.send(level, "[Axe] [#{Process.pid}] #{message}")
    end

    def default_exception_handler
      default_exception_handler ||= lambda { |e, consumer| consumer.send(:log, "#{e.class.name}: #{e.message}; offset: #{consumer.offset}", :error) }
    end
  end
end
