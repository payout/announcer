require 'resque'

module Ribbon::EventBus
  module Publishers
    class ResquePublisher < Publisher
      config_key :resque

      def publish(event)
        super

        unless event.subscriptions.empty?
          PublisherJob.set_queue(config.publisher_queue.to_sym)
          sub_queue_format = config.subscription_queue_format.to_s
          Resque.enqueue(PublisherJob, sub_queue_format, event.serialize)
        end
      end

      module PublisherJob
        def self.set_queue(queue)
          @queue = queue
        end

        def self.perform(sub_queue_format, serialized_event)
          event = Event.deserialize(serialized_event)

          event.subscriptions.each { |s|
            SubscriptionJob.set_queue(
              (sub_queue_format % {
                event: event.name,
                priority: s.priority
              }).to_sym
            )

            Resque.enqueue(SubscriptionJob, s.serialize, event.serialize)
          }
        end
      end

      module SubscriptionJob
        def self.set_queue(queue)
          @queue = queue
        end

        def self.perform(serialized_sub, serialized_event)
          subscription = Subscription.deserialize(serialized_sub)
          event = Event.deserialize(serialized_event)
          subscription.handle(event)
        end
      end
    end
  end
end