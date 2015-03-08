require 'uri'
require 'redis'
require 'redis/namespace'

module Ribbon::EventBus
  module Publishers
    class RemoteResquePublisher < Publisher
      config_key :remote_resque

      def publish(event)
        super

        # Based on Resque 1.25.2

        # Resque call stack:
        # -> Resque.enqueue(klass, *args)
        # -> Resque.enqueue_to(queue, klass, *args)
        # -> Job.create(queue, klass, *args)
        # -> Resque.push(queue, class: klass.to_s, args: args)

        # These should be the same as the args passed to Resque.enqueue in
        # ResquePublisher#publish(event).
        args = [
          event.serialize
        ]

        enqueue_to(config.queue.to_s, Publishers::ResquePublisher::PublisherJob, *args)
      end

      def redis
        @redis ||= _redis
      end

      private

      ##########################################################################
      # Methods copied from Resque v1.25.2
      ##########################################################################

      def enqueue_to(queue, klass, *args)
        # This is a functionality copy, not a direct code copy.
        # Here, I'm skipping the call to Job.create(queue, klass, *args) and
        # calling push directly.
        push(queue, class: klass.to_s, args: args)
      end

      # Resque::push(queue, items)
      def push(queue, item)
        redis.pipelined do
          watch_queue(queue)
          redis.rpush "queue:#{queue}", encode(item)
        end
      end

      # Resque::watch_queue
      def watch_queue(queue)
        redis.sadd(:queues, queue.to_s)
      end

      def encode(object)
        # This one we can call directly.
        Resque.encode(object)
      end

      ##########################################################################
      # Helper Methods
      ##########################################################################

      def _redis
        if config.redis?
          config.redis
        elsif config.redis_url?
          redis = Redis.connect(url: config.redis_url, thread_safe: true)
          Redis::Namespace.new(config.redis_namespace.to_sym, redis: redis)
        else
          raise Errors::RemoteResquePublisherError, "missing redis configuration"
        end
      end
    end
  end
end