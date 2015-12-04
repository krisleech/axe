require 'poseidon'
require "retries"
require_relative 'offset_stores/memory_offset_store'
require_relative '../shared/runnable'

module Axe
  class App
    class Consumer
      attr_reader :id, :handler, :topic, :env, :logger, :delay, :offset, :retries
      attr_reader :exception_handler

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
        @parser  = options.fetch(:parser, DefaultParser.new)
        @retries = options.fetch(:retries, 3)
      end

      # starts the consumer
      #
      def start
        status(Started, "from offset #{offset}")

        while started?
          new_messages.each do |message|
            @offset = message.offset
            process_message(message)
            perform_parent_commands
            break if stopping?
          end

          perform_parent_commands
          break if stopping? || testing?

          log "Sleeping for #{delay} seconds"
          sleep(delay)
          break if stopping?
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

      # processes a message using the handler and update the offset
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
        perform_parent_commands
        return [] if stopping?
        retry
      end

      # reads messages from parent process and maps them to commands
      #
      def perform_parent_commands
        Timeout::timeout(0.5) do
          message = @from_parent.gets
          return if message.nil?
          message.chomp!
          log "Message received from parent #{message.inspect}", :debug
          case message
          when 'stop'
            stop
          else
            raise "Unknown Message from parent process: #{message}"
          end
        end
        self
      rescue Timeout::Error
        # no-op
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
        @kafka_client ||= Poseidon::PartitionConsumer.new(id, "localhost", 9092, topic, 0, offset)
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

      def parse_message(payload)
        @parser.call(payload)
      end
    end
  end
end
