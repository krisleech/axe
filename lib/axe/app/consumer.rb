require 'poseidon'
require "retries"
require_relative 'offset_stores/memory_offset_store'
require_relative '../shared/runnable'

module Axe
  class App
    class Consumer
      attr_reader :id, :handler, :topic, :env, :logger, :delay, :offset,
                  :retries, :exception_handler, :host, :port

      prepend Runnable

      # initialize a new consumer
      #
      def initialize(options)
        @offset_store      = options.fetch(:offset_store, nil)
        @exception_handler = options.fetch(:exception_handler)
        @from_parent       = options.fetch(:from_parent)
        @id      = options.fetch(:id)
        @handler = options.fetch(:handler)
        @topic   = options.fetch(:topic)
        @env     = options.fetch(:env)
        @logger  = options.fetch(:logger)
        @delay   = options.fetch(:delay, 0.5)
        @offset  = options.fetch(:offset, next_offset)
        @parsers = Array(options.fetch(:parser, DefaultParser.new))
        @retries = options.fetch(:retries, 3)
        @host    = options.fetch(:host, 'localhost')
        @port    = options.fetch(:port, 9092)
      end

      # starts the consumer
      #
      def start
        status(Started, "from offset #{offset}")

        start_ipc

        while started? do
          new_messages.each do |message|
            @offset = message.offset
            process_message(message)
            break if stopping?
          end

          break if stopping? || testing?

          log "Sleeping for #{delay} seconds"
          sleep(delay)
        end

      rescue StandardError => e
        handle_exception(e)
        stop
      ensure
        status(Stopped, "at offset #{offset}")
        self
      end

      # Stops the consumer gracefully
      # The currently processed message will be finished
      #
      def stop
        return unless started?
        status(Stopping)
        self
      end

      # dependency injection
      #
      def kafka_client=(new_client)
        @kafka_client = new_client
      end

      # dependency injection
      #
      def offset_store=(new_store)
        @offset_store = new_store
      end

      private

      # processes a message using the handler
      # updates the offset if no exception occurs
      #
      def process_message(message)
        with_retries(max_tries: retries, handler: retry_handler) do
          handler.call(parse_message(message.value))
        end
      rescue StandardError => e
        handle_exception(e)
        stop
      else
        store_offset(offset)
        self
      end

      # retrive new messages from Kafka
      #
      def new_messages
        kafka_client.fetch.tap do |messages|
          log_message_stats(messages)
        end
      rescue Poseidon::Errors::UnknownTopicOrPartition
        log "Unknown Topic: #{topic}. Trying again in 1 second.", :warn
        sleep(1)
        return [] if stopping?
        retry
      rescue Poseidon::Connection::ConnectionFailedError
        log "Can not connect to Kafka at #{host}:#{port}. Trying again in 1 second.", :warn
        sleep(1)
        return [] if stopping?
        retry
      end

      # Starts Inter-process Communication
      # Threaded so the main thread is not blocked
      # Commands are received on a read pipe
      #
      def start_ipc
        Thread.new do
          log "IPC started", :debug
          while started? do
            command = @from_parent.gets # blocking
            next if command.nil?
            command.chomp!
            log "Command received from parent #{command.inspect}", :debug
            handle_command(command)
          end
          log "IPC stopped", :debug
        end
        self
      end

      # handle an external command
      #
      def handle_command(command)
        case command
        when 'stop'
          stop
        else
          raise "Unknown command received: #{command}"
        end
        self
      end

      def handle_exception(e)
        exception_handler.call(e, self)
      end

      # called when an exception occurs but it can be retried
      def retry_handler
        @retry_handler ||= Proc.new do |exception, attempt_number, total_delay|
          log("#{exception.class.name}: #{exception.message}; attempt: #{attempt_number}; offset: #{offset}", :warn)
        end
      end

      def fetch_offset
        offset_store[id]
      end

      def store_offset(new_offset)
        offset_store[id] = new_offset
      end

      def next_offset
        (fetch_offset || -1) + 1
      end

      def testing?
        @env == 'test'
      end

      def kafka_client
        @kafka_client ||= Poseidon::PartitionConsumer.new(id, host, port, topic, 0, offset)
      end

      def offset_store
        @offset_store ||= MemoryOffsetStore.new
      end

      def log(message, level = :info)
        return unless logger
        logger.send(level, "[#{id}] [#{topic}] #{message}")
      end

      def log_message_stats(messages)
        log("#{messages.size} messages in batch", :debug)
        log("offset #{messages.first.offset}..#{messages.last.offset}", :debug) unless messages.empty?
      end

      # passes payload through a chain of parsers
      #
      # @param payload <String>
      #
      def parse_message(payload)
        @parsers.inject(payload) do |memo, parser|
          parser.call(memo)
        end
      end
    end
  end
end
