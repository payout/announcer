require 'plugins'

module Announcer
  module Plugins
    class Plugin < ::Plugins::Plugin
      include Mixins::HasInstance
      include Mixins::HasConfig

      config_key :plugins

      def initialize(plugins, params={})
        super(plugins)
        @instance = plugins.component
        @_params = params || {}
      end

      def config
        @__config ||= super.merge_hash!(@_params)
      end
    end
  end
end
