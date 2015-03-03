module Ribbon
  module EventBus
    autoload(:Instance, 'ribbon/event_bus/instance')
    autoload(:Errors, 'ribbon/event_bus/errors')
    autoload(:Config, 'ribbon/event_bus/config')
    autoload(:Event, 'ribbon/event_bus/event')
    autoload(:Subscription, 'ribbon/event_bus/subscription')
    autoload(:Publishers, 'ribbon/event_bus/publishers')
    autoload(:Mixins, 'ribbon/event_bus/mixins')

    module_function

    def method_missing(meth, *args, &block)
      instance.send(meth, *args, &block)
    end

    def instance(name=:primary)
      _registered_instances[name.to_sym] || Instance.new(name)
    end

    def _registered_instances
      @__registered_instances ||= {}
    end

    def _register_instance(instance)
      if _registered_instances.key?(instance.name)
        raise Errors::DuplicateInstanceNameError, instance.name
      else
        _registered_instances[instance.name] = instance
      end
    end
  end
end

# Create a shortcut
EventBus = Ribbon::EventBus