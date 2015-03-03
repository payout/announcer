module Ribbon::EventBus::Publishers
  class SubscriptionsPublisher < Publisher
    def publish(event)
      super
      event.subscriptions.each { |subscription| subscription.handle(event) }
    end
  end
end