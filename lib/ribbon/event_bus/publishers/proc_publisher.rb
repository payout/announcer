module Ribbon::EventBus
  module Publishers
    class ProcPublisher < Publisher
      def initialize(instance=nil, &block)
        super

        raise Errors::MissingProcError unless block_given?
        raise Errors::InvalidArityError, 'Proc arity must be 1' unless block.arity == 1
        @_block = block
      end

      def new(instance=nil)
        self.class.new(instance, &@_block)
      end

      def publish(event)
        super
        @_block.call(event)
      end
    end
  end
end