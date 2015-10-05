module Announcer
  module Mixins
    module HasConfig
      def self.included(base)
        raise "HasConfig requires HasInstance" unless base < HasInstance
        base.extend(ClassMethods)
      end

      module ClassMethods
        def config_key(key)
          config_keys << key.to_sym
        end

        def config_keys(*keys)
          unless keys.empty?
            _has_config_values[:keys] = keys.map(&:to_sym)
          else
            _has_config_values[:keys] ||= _has_config_ancestor_keys
          end
        end

        def _has_config_ancestor_keys
          ancestors[1] < HasConfig ? ancestors[1].config_keys.dup : []
        end

        def _has_config_values
          @__has_config_values ||= {}
        end
      end

      def config
        _has_config_config
      end

      def _has_config_config
        @__has_config_config ||= _has_config_load_config.dup
      end

      def _has_config_load_config
        keys = self.class.config_keys
        keys.inject(instance.config) { |c, k| c.send(k) }
      end
    end
  end
end
