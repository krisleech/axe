require 'pry'
require 'poseidon'
require 'pstore'

require 'celluloid/current'

module Axe

  # A consumer fetches a batch of messages from a topic
  # It maintains the position (offset) in the message stream
  #
  # offset is actually next_offset, rename
  class Consumer
    include Celluloid
    include Celluloid::Internals::Logger

    attr_reader :id, :topic, :handler, :pool_size, :offset,
                :max_batch_size, :status

    exclusive

    def initialize(options)
      @id = options.fetch(:id)
      @topic = options.fetch(:topic)
      @handler = options.fetch(:handler)
      @pool_size = options.fetch(:pool_size, 1)
      @offset_store = options.fetch(:offset_store)
      @offset = options.fetch(:offset, @offset_store.get(id))
      @max_batch_size = 1048576 # 1MB
      # @logger = options.fetch(:logger, nil)
      @status = :stopped
      super()
    end

    def call
      @status = :running

      log("[CON##{id}] Running")

      messages = client.fetch

      log("[CON##{id}] Processing #{messages.size} messages")

      messages.each do |m|
        break unless @status == :running

        log("[CON##{id}] Processing message wth offset #{m.offset}")

        handler.call(m.value)
        increment_offset
      end

      log("[CON##{id}] stopped")
      @status = :stopped
    end

    def stop
      log("[CON##{id}] stopping")
      @status = :stopping
    end

    def running?
      @status == :running
    end

    def stopped?
      @status == :stopped
    end

    private

    def log(message)
      info(message)
    end

    # next offset is stored on disk
    def increment_offset
      @offset += 1
      @offset_store.put(id, offset)
    end

    # Connect to Kafka queue via TCP
    def client
      @client ||= Poseidon::PartitionConsumer.new(id,
                                                 "localhost", 9092,
                                                 topic,
                                                 0,
                                                 offset,
                                                 max_bytes: max_batch_size)
    end
  end

  # Store offsets keyed by consumer id
  # Needs to be threadsafe?
  # Could have one instance per consumer, instead of sharing an instance
  # NOTE: we cant use one PStore for all consumers, otherwise we get a
  # PStore::Error: nested transaction error. So maybe change to use a locked
  # file containing the id.
  #
  # We do not need to lock the file, since we do not read, then write, just
  # write over the entire file. We need atomic write, so reader cannot get a
  # half written file.
  # Can we lock for read+writes http://apidock.com/ruby/File/flock
  class OffsetStore
    def initialize
      @offsets = {}
    end

    def get(id)
      pstore = PStore.new(id + '.pstore')
      pstore.transaction(true) do
        pstore.fetch(id, 0)
      end
    end

    def put(id, offset)
      pstore = PStore.new(id + '.pstore')
      pstore.transaction do
        pstore[id] = offset
      end
    end
  end

  class MemoryOffsetStore
    def initialize
      @offsets = {}
    end

    def get(id)
      @offsets[id] ||= 0
    end

    def put(id, offset)
      @offsets[id] = offset
    end
  end


  class App
    # include Celluloid

    attr_reader :consumers, :status, :delay

    def initialize
      @consumers = []
      @status = :stopped
      @log = ::Logger.new('app.log')
      Celluloid.logger = @log
      @delay = 0.5
    end

    # TODO: ensure consumer id not taken
    def register(options)
      consumer = Consumer.new({ offset_store: offset_store, logger: log, max_batch_size: 1048 }.merge(options))
      @consumers << consumer
      log.info "registered consumer #{consumer.id}"
    end

    def run
      @status = :running

      log.info "running app Thread: Process: #{Process.pid}, #{Thread.current.object_id}, Fiber: #{Fiber.current.object_id}"

      while running? do
        consumers.each do |c|

          break unless running?

          c.async.call
        end

        # blocking here because id, offset messages need to wait in mailbox
        # behind events being processed.
        # fix by making making calling of handler async?
        # consumers.each do |c|
        #   log.info("Consumer##{c.id} at #{c.offset}")
        # end

        break unless running?

        log.info "Actors up: #{Celluloid::Actor.all.size}"
        log.info "Actors up: #{Celluloid::Actor.all.inspect}"
        log.info "sleeping for #{delay} seconds"

        sleep(delay)
      end

      # this will not work as it will wait in the mailbox...?
      # all #terminate on each actor
      consumer.each(&:stop)

      # will this block too, what about mailbox.size == 0
      while consumer.any?(&:running?) do
        log.info "Waiting for consumers to finish"
        sleep(1)
      end

      # proberbly we need to do a graceful shutdown in the trap, where it waits
      # until all mailboxes are zero. or app.stopped? == true

      log.info 'app stopped'
    end

    def running?
      @status == :running
    end

    def stopped?
      @status == :stopped
    end

    def stopping?
      @status == :stopping
    end

    def stop
      log.info 'Stopping app'
      @status = :stopping
    end

    private

    def offset_store
      # @offset_store ||= MemoryOffsetStore.new
      @offset_store ||= OffsetStore.new
    end

    def log
      @log
    end
  end
end
