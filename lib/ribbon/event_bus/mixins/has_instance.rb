module Ribbon
  module EventBus::Mixins
    module HasInstance
      def instance
        (defined?(@instance) && @instance) || EventBus.instance
      end
    end
  end
end