module Announcer
  class Event
    include Mixins::HasInstance
    include Mixins::HasConfig
    include Mixins::Serializable

    config_key :events
    serialize_with :name, :instance, :params

    attr_reader :name
    attr_reader :params

    def initialize(name, params={})
      raise ArgumentError, 'missing event name' unless name.respond_to?(:to_sym)
      @name = name.to_sym
      _evaluate_params(params)
    end

    def self.load_from_serialized(name, instance, params)
      new(name, params.merge(instance: instance))
    end

    def [](key)
      params[key]
    end

    def publish
      plugins.perform(:publish, self) { |event|
        instance.publishers.each { |p| p.publish(event) }
      }
    end

    def subscriptions
      instance.subscriptions_to(self)
    end

    def to_s
      "Event(#{name}" <<
        (params && !params.empty? && ", #{params.inspect}" or '') <<
        ")"
    end

    private

    ############################################################################
    # Parameter Evaluation Logic
    #
    # This evaluates the parameters passed to the initializer.
    ############################################################################

    ###
    # Root evaluation method.
    ###
    def _evaluate_params(params)
      unless params.is_a?(Hash)
        raise ArgumentError, 'event parameters must be a hash'
      end

      params = params.dup
      @instance = params.delete(:instance)
      @params = _sanitize_params(params)
    end

    ###
    # Sanitize the event params.
    # Prevents passing values that could cause errors later in Announcer.
    ###
    def _sanitize_params(params)
      Hash[params.map { |key, value| [key.to_sym, _sanitize_value(key, value)] }].freeze
    end

    # Sanitize an array.
    def _sanitize_array(key, array)
      array.map { |value| _sanitize_value(key, value) }.freeze
    end

    # Sanitize an individual value.
    def _sanitize_value(key, value)
      case value
      when String
        value.dup.freeze
      when Symbol, Integer, Float, NilClass, TrueClass, FalseClass
        value
      when Array
        _sanitize_array(key, value)
      when Hash
        _sanitize_params(value)
      else
        raise Errors::UnsafeValueError.new(key, value)
      end
    end
  end # Event
end # Announcer
