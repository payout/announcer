require 'resque'
require 'redis'
require 'celluloid/current'

module Announcer
  module Publishers
    class AsyncResquePublisher < Publisher
      config_key :resque

      attr_reader :resque

      def initialize(instance=nil, params={})
        super
        @resque = config.resque? ? config.resque : Resque
      end

      def worker_id
        @__worker_id ||= "announcer_resque_worker_#{object_id}".to_sym
      end

      ##
      # The suprvisor created in the initializer will restart the PublisherWorker
      # but there can be a short period of time when the actor returned by
      # Celluloid::Actor[...] is dead. To avoid that we sleep for a millisecond
      # to give it time to create a new worker thread.  We try three times before
      # giving up.
      #
      # This should ensure that it's unlikely for a dead worker to be returned.
      # However, if a dead worker is returned, then async calls will silently
      # fail, allowing normal execution. This makes firing events best-effort.
      def worker
        # Retrieve the PublisherWorker or start the supervisor.
        w = Celluloid::Actor[worker_id] || PublisherWorker.supervise(
          args: [self],
          as: worker_id
        ).send(worker_id)

        3.times {
          if w.dead?
            sleep(0.001)
            w = Celluloid::Actor[worker_id]
          else
            break
          end
        }

        w
      end

      ##
      # Needs to exist for the ResquePublisher::PublisherJob to succeed.
      def subscription_queue_formatter
        ResquePublisher.subscription_queue_formatter(config)
      end

      def publish(event)
        super
        worker.async.publish(event) unless event.subscriptions.empty?
      end

      class PublisherWorker
        include Celluloid

        attr_reader :publisher

        def initialize(publisher)
          @publisher = publisher
        end

        def publish(event)
          publisher.resque.enqueue_to(
            publisher.config.publisher_queue.to_sym,
            ResquePublisher::PublisherJob,
            event.serialize,
            :async_resque
          )
        end
      end # PublisherWorker
    end
  end
end
