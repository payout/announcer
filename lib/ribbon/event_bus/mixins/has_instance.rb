module Ribbon
  module EventBus::Mixins
    module HasInstance
      def instance
        (defined?(@instance) && @instance) || EventBus.instance
      end

      def plugins
        instance.send(:plugins)
      end
    end
  end
end