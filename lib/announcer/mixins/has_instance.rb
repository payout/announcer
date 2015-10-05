module Announcer
  module Mixins
    module HasInstance
      def instance
        (defined?(@instance) && @instance) || Announcer.instance
      end

      def plugins
        instance.send(:plugins)
      end
    end
  end
end
