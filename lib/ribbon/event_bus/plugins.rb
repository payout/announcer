module Ribbon::EventBus
  module Plugins
    autoload(:Plugin,        'ribbon/event_bus/plugins/plugin')
    autoload(:LoggingPlugin, 'ribbon/event_bus/plugins/logging_plugin')
  end
end