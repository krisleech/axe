require 'poseidon'
require "retries"
require_relative 'memory_offset_store'

module Axe
  class App
    class Consumer
      attr_reader :id, :handler, :topic, :env, :logger, :delay, :offset
      attr_reader :exception_handler

      Stopped  = :stopped
      Started  = :started
      Stopping = :stopping

      # initialize a new consumer
      #
      def initialize(options)
        @id      = options.fetch(:id)
        @handler = options.fetch(:handler)
        @topic   = options.fetch(:topic)
        @env     = options.fetch(:env)
        @logger  = options.fetch(:logger)
        @delay   = options.fetch(:delay, 0.5)
        @offset  = options.fetch(:offset, next_offset)
        @exception_handler = options.fetch(:exception_handler)
        @status  = Stopped
      end

      # starts the consumer
      #
      def start
        status(Started)

        while started?
          messages = kafka_client.fetch

          log_message_stats(messages)

          messages.each do |message|
            @offset = message.offset

            begin
              with_retries(max_tries: 3, handler: retry_handler) do
                handler.call(message.value)
              end
            rescue StandardError => e
              handle_exception(e)
              stop
            else
              store_offset(offset)
            end

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
        status(Stopped)
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

      # Returns true when consumer has been started
      #
      def started?
        @status == Started
      end

      # Returns true when the consumer is in the process of stopping
      #
      def stopping?
        @status == Stopping
      end

      # Returns true when the consumer is stopped
      #
      def stopped?
        @status == Stopped
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

      def status(new_status)
        @status = new_status
        log @status.to_s.capitalize
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
        logger.send(level, "[#{id}] [#{topic}] #{message}")
      end

      def log_message_stats(messages)
        log("#{messages.size} messages in batch", :debug)
        log("offset #{messages.first.offset}..#{messages.last.offset}", :debug) unless messages.empty?
      end
    end
  end
end
