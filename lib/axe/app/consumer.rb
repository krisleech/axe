require 'poseidon'

module Axe
  class App
    class Consumer
      attr_reader :id, :handler, :topic, :env, :logger, :delay, :offset

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
        @status  = Stopped
      end

      def start
        log "Started"
        @status = Started

        while !stopping?
          messages = kafka_client.fetch
          log "#{messages.size} messages in batch"

          messages.each do |message|
            @offset = message.offset

            handler.call(message.value)

            break if stopping?
          end

          break if testing?

          log "Sleeping for #{delay} seconds"
          sleep(delay)
        end

        @status = Stopped
        log "Stopped"
      end

      def stop
        log "Stopping"
        @status = Stopping
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

      private

      def testing?
        @env == 'test'
      end

      def kafka_client
        @kafka_client ||= Poseidon::PartitionConsumer.new(id, "localhost", 9092, topic, 0, :earliest_offset)
      end

      def log(message, level = :info)
        logger.send(level, "[#{id}] [#{Process.pid}] #{message}")
      end
    end
  end
end
