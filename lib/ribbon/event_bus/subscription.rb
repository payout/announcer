require 'digest'

module Ribbon::EventBus
  class Subscription
    include Mixins::HasInstance
    include Mixins::HasConfig
    include Mixins::Serializable

    config_key :subscriptions
    serialize_with :instance, :locator

    attr_reader :name
    attr_reader :event_name
    attr_reader :priority
    attr_reader :locator

    PRIORITY_SYMBOL_TO_INTEGER_MAP = {
      highest: 1,
      high: 3,
      medium: 5,
      low: 7,
      lowest: 10
    }.freeze

    def initialize(event_name, params={}, &block)
      @event_name = event_name.to_sym
      @_block = block

      _evaluate_params(params)

      @name ||= _path
      @locator = _generate_locator

      instance._register_subscription(self)
    end

    def self.load_from_serialized(instance, locator)
      instance.find_subscription(locator)
    end

    def handle(event)
      raise Errors::UnexpectedEventError, 'wrong name' unless event.name == event_name
      raise Errors::UnexpectedEventError, 'wrong instance' unless event.instance == instance

      plugins.perform(:subscription, self, event) { |subscription, event|
        @_block.call(event)
      }
    end

    def to_s
      "Subscription(#{event_name}, #{name})"
    end

    private

    def _path
      @__path ||= _determine_path
    end

    def _determine_path
      path = File.expand_path('../..', __FILE__)
      non_event_bus_caller = caller.find { |c| !c.start_with?(path) }

      unless non_event_bus_caller
        # This is not expected to occur.
        raise Errors::SubscriptionError, "Could not find non-EventBus caller"
      end

      non_event_bus_caller
    end

    def _generate_locator
      Digest::MD5.hexdigest(_path).to_sym
    end

    ############################################################################
    # Parameter Evaluation Logic
    #
    # This evaluates the parameters passed to the initializer.
    ############################################################################

    ###
    # Root evaluation method.
    ###
    def _evaluate_params(params)
      @instance = params[:instance]
      @name = params[:name]
      @priority = _evaluate_priority(params[:priority])
    end

    ###
    # Priority evaluation
    ###
    def _evaluate_priority(priority)
      case priority
      when Integer
        _evaluate_priority_int(priority)
      when String, Symbol
        _evaluate_priority_symbol(priority.to_sym)
      when NilClass
        _evaluate_priority_nil
      else
        raise Errors::InvalidPriorityError, priority.inspect
      end
    end

    # Evaluate an integer as a priority.
    def _evaluate_priority_int(int)
      raise Errors::InvalidPriorityError, int unless int > 0 && int <= 10
      int
    end

    # Evaluate a symbol as a priority.
    def _evaluate_priority_symbol(sym)
      if (priority = PRIORITY_SYMBOL_TO_INTEGER_MAP[sym])
        _evaluate_priority(priority)
      else
        raise Errors::InvalidPriorityError, sym.inspect
      end
    end

    # Evaluate nil as a priority.
    def _evaluate_priority_nil
      # Need to specify value explicitly here, otherwise in the call to
      # _evaluate_priority, the case statement won't recognize it as a Symbol.
      # That's because when calls Symbol::=== to evaluate a match.
      priority = config.default_priority

      if priority
        _evaluate_priority(priority)
      else
        raise Errors::InvalidPriorityError, priority.inspect
      end
    end
  end # Event
end # Ribbon::EventBus