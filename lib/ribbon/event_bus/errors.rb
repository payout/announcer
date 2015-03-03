module Ribbon::EventBus
  module Errors
    class Error < StandardError; end
    class DuplicateInstanceNameError < Error; end
    class NoPublishersDefinedError < Error; end

    ###
    # Instance Errors
    ###
    class InstanceError < Error; end

    ###
    # Event Errors
    ###
    class EventError < Error; end
    class UnsafeValueError < EventError
      def initialize(key, value)
        super("#{key.inspect} => #{value.inspect}")
      end
    end # UnsafeValueError

    ###
    # Subscription Errors
    ###
    class SubscriptionError < Error; end
    class InvalidPriorityError < SubscriptionError; end
    class UnexpectedEventError < SubscriptionError; end

    ###
    # Publisher Errors
    ###
    class PublisherError < Error; end
    class InvalidPublisherError < PublisherError; end
    class InvalidPublisherNameError < PublisherError; end

    # RemoteResquePublisher Errors
    class RemoteResquePublisherError < PublisherError; end

    # ProcPublisherErrors
    class ProcPublisherError < PublisherError; end
    class MissingProcError < ProcPublisherError; end
    class InvalidArityError < ProcPublisherError; end

    ###
    # Serializable Errors
    ###
    class SerializableError < Error; end
  end
end