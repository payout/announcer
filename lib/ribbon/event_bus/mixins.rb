module Ribbon::EventBus
  module Mixins
    autoload(:HasInstance, 'ribbon/event_bus/mixins/has_instance')
    autoload(:HasConfig, 'ribbon/event_bus/mixins/has_config')
    autoload(:Serializable, 'ribbon/event_bus/mixins/serializable')
  end
end