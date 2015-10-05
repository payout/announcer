module Announcer
  autoload(:Instance,     'announcer/instance')
  autoload(:Config,       'announcer/config')
  autoload(:Publishers,   'announcer/publishers')
  autoload(:Plugins,      'announcer/plugins')
  autoload(:Event,        'announcer/event')
  autoload(:Subscription, 'announcer/subscription')
  autoload(:Mixins,       'announcer/mixins')
  autoload(:Errors,       'announcer/errors')

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
