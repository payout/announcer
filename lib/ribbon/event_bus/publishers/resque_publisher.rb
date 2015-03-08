require 'resque'

module Ribbon::EventBus
  module Publishers
    class ResquePublisher < Publisher
      config_key :resque

      def initialize(instance=nil, params={})
        super
        _disallow_multiple_per_instance
      end

      def publish(event)
        super

        unless event.subscriptions.empty?
          PublisherJob.set_queue(config.publisher_queue.to_sym)
          Resque.enqueue(PublisherJob, event.serialize)
        end
      end

      module PublisherJob
        def self.set_queue(queue)
          @queue = queue
        end

        def self.perform(serialized_event)
          event = Event.deserialize(serialized_event)
          instance = event.instance

          publisher = instance.find_publisher(:resque)
          raise Errors::PublisherError, 'No ResquePublisher found' unless publisher
          sub_queue_format = publisher.config.subscription_queue_format

          instance.plugins.perform(:resque_publish, event) do |event|
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
      end # PublisherJob

      module SubscriptionJob
        def self.set_queue(queue)
          @queue = queue
        end

        def self.perform(serialized_sub, serialized_event)
          subscription = Subscription.deserialize(serialized_sub)
          event = Event.deserialize(serialized_event)
          subscription.handle(event)
        end
      end # SubscriptionJob

      private
      def _disallow_multiple_per_instance
        if instance.has_publisher?(:resque)
          raise Errors::PublisherError,
            "cannot have multiple ResquePublishers in an EventBus instance"
        end
      end
    end
  end
end