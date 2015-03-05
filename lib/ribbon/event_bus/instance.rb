require 'ribbon/plugins'

module Ribbon
  module EventBus
    DEFAULT_CONFIG_PATH = File.expand_path('../../../../config/defaults.yml', __FILE__).freeze

    ##############################################################################
    # Instance
    #
    # Represents an instance of the EventBus. Allows multiple Instances to be
    # created with separate configuration, subscriptions, etc. Primarily intended
    # to help testing, but there are practical use-cases as well.
    ##############################################################################
    class Instance
      include Mixins::Serializable
      include Ribbon::Plugins::ComponentMixin

      serialize_with :name

      plugin_loader do |plugin|
        case plugin
        when String, Symbol
          begin
            Plugins.const_get(
              plugin.to_s.split('_').map(&:capitalize).join + 'Plugin'
            )
          rescue
            nil # Let the Plugins gem handle this.
          end
        end
      end

      attr_reader :name
      attr_reader :publishers

      def initialize(name=nil)
        if name
          @name = name.to_sym
          EventBus._register_instance(self) if @name
        end

        _load_default_config
      end

      def self.load_from_serialized(name)
        if name
          EventBus.instance(name)
        else
          raise Errors::InstanceError, "Can't deserialize an unnamed Instance"
        end
      end

      def config(&block)
        (@__config ||= Config.new).tap { |config|
          if block_given?
            config.define(&block)
            _process_config
          end
        }
      end

      def publish(*args)
        raise Errors::NoPublishersDefinedError unless publishers && !publishers.empty?
        _args_to_event(*args).publish
      end

      def subscribe_to(event_name, params={}, &block)
        Subscription.new(event_name, params.merge(instance: self), &block)
      end

      def subscriptions_to(event_or_name)
        event_name = event_or_name.is_a?(Event) ? event_or_name.name : event_or_name.to_sym
        _registered_subscriptions_to(event_name).dup
      end

      def find_subscription(locator)
        _subscriptions_by_locators[locator]
      end

      def _register_subscription(subscription)
        if _subscriptions_by_locators[subscription.locator]
          # This is not expected to occur
          raise Errors::SubscriptionError, "duplicate locator: #{subscription.locator.inspect}"
        else
          _subscriptions_by_locators[subscription.locator] = subscription
       end

        _registered_subscriptions_to(subscription.event_name)
          .push(subscription)
          .sort! { |x, y| x.priority <=> y.priority }
      end

      private
      def _registered_subscriptions_to(event_name)
        (@__registered_subscriptions ||= {})[event_name] ||= []
      end

      def _subscriptions_by_locators
        @__registered_subscriptions_by_locator ||= {}
      end

      def _load_default_config
        config.merge_config_file!(DEFAULT_CONFIG_PATH)
      end

      # Attempt to convert *args to an event object.
      def _args_to_event(name_or_event, params={})
        raise ArgumentError, 'event parameters must be a hash' unless params.is_a?(Hash)

        case name_or_event
        when Event
          name_or_event.tap { |e| e.instance_variable_set(:@instance, self) }
        else
          Event.new(name_or_event, params.merge(instance: self))
        end
      end # _args_to_event

      def _process_config
        @publishers = _load_publishers.dup.freeze
      end

      def _load_publishers
        Publishers.load_for_instance(self)
      end
    end # Instance
  end # EventBus
end # Ribbon