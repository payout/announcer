require 'digest'

module Ribbon::EventBus
  class Subscription
    include Mixins::HasInstance
    include Mixins::HasConfig
    include Mixins::Serializable

    config_key :subscriptions
    serialize_with :instance, :identifier

    attr_reader :name
    attr_reader :event_name
    attr_reader :priority
    attr_reader :identifier

    def initialize(event_name, params={}, &block)
      @event_name = event_name.to_sym
      @_block = block

      _evaluate_params(params)

      @identifier = _generate_identifier

      if instance.find_subscription(identifier)
        raise Errors::DuplicateIdentifierError, "give this subscription a unique name"
      else
        instance._register_subscription(self)
      end
    end

    def self.load_from_serialized(instance, identifier)
      instance.find_subscription(identifier)
    end

    def handle(event)
      raise Errors::UnexpectedEventError, 'wrong name' unless event.name == event_name
      raise Errors::UnexpectedEventError, 'wrong instance' unless event.instance == instance

      plugins.perform(:subscription, self, event) { |subscription, event|
        @_block.call(event)
      }
    end

    def to_s
      "Subscription(on #{event_name}: #{name || _path})"
    end

    private

    def _path
      @__path ||= _determine_path
    end

    ##
    # Determines the file path of the ruby code defining the subscription.
    # It's important that this is called from within the initializer to get the
    # desired effect.
    def _determine_path
      path = File.expand_path('../..', __FILE__)

      # Will be something like:
      # "/path/to/file.rb:47:in `method_name'"
      non_event_bus_caller = caller.find { |c| !c.start_with?(path) }

      unless non_event_bus_caller
        # This is not expected to occur.
        raise Errors::SubscriptionError, "Could not find non-EventBus caller"
      end

      non_event_bus_caller
    end

    ##
    # Generates a unique identifier for this subscription which will be used to
    # "serialize" it.
    #
    # The goal here is to generate a identifier that is the same across different
    # processes and servers and that ideally changes infrequently between
    # application versions, but when it does change, it should do so predictably.
    def _generate_identifier
      # Cut off everything from the line number onward. That way, the identifier
      # does not change when the subscription block moves to a different line.
      index = _path.rindex(/:\d+:/) - 1
      path = _path[0..index]

      raise Errors::SubscriptionError, "Invalid path: #{path}" unless File.exists?(path)

      Digest::MD5.hexdigest("#{path}:#{event_name}:#{name}").to_sym
    end

    def _symbol_to_priority(sym)
      (@__symbol_to_priority_map ||= _generate_priority_shortcut_map)[sym]
    end

    def _generate_priority_shortcut_map(max_priority=config.max_priority)
      {}.tap { |map|
        map.merge!(highest: 1, lowest: max_priority)
        map[:medium] = (map[:lowest] / 2.0).ceil
        map[:high] = (map[:medium] / 2.0).ceil
        map[:low] = ((map[:lowest] + map[:medium]) / 2.0).ceil
      }.freeze
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
      @name = params[:name].to_s
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
      raise Errors::InvalidPriorityError, int unless int > 0 && int <= config.max_priority
      int
    end

    # Evaluate a symbol as a priority.
    def _evaluate_priority_symbol(sym)
      if (priority = _symbol_to_priority(sym))
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