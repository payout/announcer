require 'yaml'

module Ribbon::EventBus
  class Config
    # Putting this here instead of in Errors because I may move this into a
    # separate gem.
    class ConfigError < StandardError; end
    class NotAddableError < ConfigError; end

    class ProcArray < Array
      def push(*procs)
        raise ConfigError, "May only add blocks" unless procs.all? { |p| p.is_a?(Proc) }
        super
      end

      def call(*args, &block)
        map { |x| x.call(*args, &block) }
      end
    end

    attr_reader :name

    def initialize(name=nil, &block)
      @name = name
      define(&block) if block_given?
    end

    def define(&block)
      case block.arity
      when 0 then instance_eval(&block)
      when 1 then block.call(self)
      else   raise ConfigError, 'invalid config block arity'
      end
    end

    # Deep dup all the values.
    def dup
      super.tap do |new_config|
        new_config.instance_variable_set(
          :@_nested,
          Hash[
            _nested.map { |key, object|
              [
                key,
                object.is_a?(Config) ? object.dup : object
              ]
            }
          ]
        )
      end
    end

    def method_missing(meth, *args, &block)
      meth_str = meth.to_s

      if /^(\w+)\=$/.match(meth_str)
        _set($1, *args, &block)
      elsif args.length > 0 || block_given?
        _add(meth, *args, &block)
      elsif /^(\w+)\?$/.match(meth_str)
        !!_get($1)
      else
        object = _get(meth)
        object = _set(meth, Config.new((name ? "#{name}." : '') + meth_str)) unless object
        object
      end
    end

    def nested(name)
      _nested[name.to_sym]
    end

    def nest_value(name, value)
      nested()
    end

    def nested_values(key)
      _nested_values[key.to_sym]
    end

    def nested_configs(namespace)
      _nested_configs[namespace.to_sym]
    end

    def merge_hash!(hash)
      hash.each { |k, v|
        if v.is_a?(Hash)
          send(k).merge_hash!(v)
        else
          send("#{k}=", v)
        end
      }

      self
    end

    def merge_config_file!(file)
      merge_hash!(YAML.load_file(file))
    end

    private
    def _get(key)
      _nested[key.to_sym]
    end

    def _set(key, *args, &block)
      object = _args_to_object(*args, &block)
      _nested[key.to_sym] = object
    end

    def _add(key, *args, &block)
      raise NotAddableError, self.inspect if @_value && !@_value.is_a?(Array)
      object = _args_to_object(*args, &block)
      _set(key, object.is_a?(Proc) ? ProcArray.new : []) unless _get(key)
      _get(key).push(object)
    end

    def _args_to_object(*args, &block)
      if args.length == 1
        args.first
      elsif args.length > 1
        args
      elsif block_given?
        block
      else
        raise ConfigError, 'must pass value or block'
      end
    end

    def _nested
      @_nested ||= {}
    end
  end # Config
end # Ribbon::EventBus