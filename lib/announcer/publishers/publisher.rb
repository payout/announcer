module Announcer
  module Publishers
    class Publisher
      include Mixins::HasInstance
      include Mixins::HasConfig
      config_key :publishers

      def initialize(instance=nil, params={})
        @instance = instance
        @_params = params
      end

      def config
        @__config ||= super.merge_hash!(@_params)
      end

      ###
      # #publish(event)
      #
      # This method should be overridden by a subclass. Make sure to call "super"
      # so that proper sanity checks can be performed.
      ###
      def publish(event)
        unless event.instance == instance
          raise Errors::PublisherError, "Event for different instance"
        end
      end
    end
  end
end
