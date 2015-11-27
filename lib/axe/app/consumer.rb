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

      def start
        log "Started"
        @status = Started


        while !stopping?
          messages = kafka_client.fetch

          log "#{messages.size} messages in batch"
          log "offset #{messages.first.offset}..#{messages.last.offset}" unless messages.empty?


          messages.each do |message|
            @offset = message.offset

            begin
              with_retries(max_tries: 3, handler: retry_handler) do
                handler.call(message.value)
              end
            rescue StandardError => e
              exception_handler.call(e.exception("handler: #{id}; offset: #{offset}; #{e.message}"))
              stop
              break
            else
              store_offset(offset)
            end

            break if stopping?
          end

          break if testing? || stopping?

          log "Sleeping for #{delay} seconds"
          sleep(delay)
        end

        @status = Stopped
        log "Stopped"

        self
      rescue StandardError => e
        # move stop and status to else block
        stop
        @status = Stopped
        exception_handler.call(e.exception("handler: #{id}; offset: #{offset}; #{e.message}"))
        self
      end

      def stop
        log "Stopping"
        @status = Stopping
        self
      end

      def started?
        @status == Started
      end

      def stopping?
        @status == Stopping
      end

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

      def retry_handler
        @retry_handler ||= Proc.new do |exception, attempt_number, total_delay|
          log("ERROR: #{exception.class.name}: #{exception.message}; attempt: #{attempt_number}; offset: #{offset}")
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
        logger.send(level, "[#{id}] [#{Process.pid}] #{message}")
      end
    end
  end
end
