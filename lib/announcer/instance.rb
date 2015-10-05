require 'ribbon/plugins'

module Announcer
  DEFAULT_CONFIG_PATH = File.expand_path('../../../config/defaults.yml', __FILE__).freeze

  ##############################################################################
  # Instance
  #
  # Represents an instance of the Announcer. Allows multiple Instances to be
  # created with separate configuration, subscriptions, etc. Primarily intended
  # to help testing, but there are practical use-cases as well.
  ##############################################################################
  class Instance
    include Mixins::Serializable
    include Ribbon::Plugins::ComponentMixin

    serialize_with :name

    plugin_loader do |plugin|
      _translate_object_to_plugin(plugin)
    end

    attr_reader :name
    attr_reader :publishers

    def initialize(name=nil)
      if name
        @name = name.to_sym
        Announcer._register_instance(self) if @name
      end

      _load_default_config
    end

    def self.load_from_serialized(name)
      if name
        Announcer.instance(name)
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

    def plugin(*args)
      config { plugin(*args) }
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

    def find_subscription(identifier)
      _subscriptions_by_identifiers[identifier]
    end

    def find_publisher(publisher)
      klass = Publishers.load(publisher)
      publishers && publishers.find { |pub| pub.is_a?(klass) }
    end

    def has_publisher?(publisher)
      !!find_publisher(publisher)
    end

    def _register_subscription(subscription)
      if _subscriptions_by_identifiers[subscription.identifier]
        # This is not expected to occur
        raise Errors::SubscriptionError, "duplicate identifier: #{subscription.identifier.inspect}"
      else
        _subscriptions_by_identifiers[subscription.identifier] = subscription
     end

      _registered_subscriptions_to(subscription.event_name)
        .push(subscription)
        .sort! { |x, y| x.priority <=> y.priority }
    end

    private
    def _translate_object_to_plugin(object)
      case object
      when String, Symbol
        _translate_string_to_plugin(object.to_s)
      end
    end

    def _translate_string_to_plugin(string)
      begin
        Plugins.const_get(
          string.split('_').map(&:capitalize).join + 'Plugin'
        )
      rescue
        nil # Let the Plugins gem handle this.
      end
    end

    def _registered_subscriptions_to(event_name)
      (@__registered_subscriptions ||= {})[event_name] ||= []
    end

    def _subscriptions_by_identifiers
      @__registered_subscriptions_by_identifier ||= {}
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
      _update_plugins
    end

    def _load_publishers
      Publishers.load_for_instance(self)
    end

    def _update_plugins
      plugins.clear

      if config.plugin?
        config.plugin.each { |plugin|
          plugin = [plugin] unless plugin.is_a?(Array)
          plugins.add(*plugin)
        }
      end
    end
  end # Instance
end # Announcer
