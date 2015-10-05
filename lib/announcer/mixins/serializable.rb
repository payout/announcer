require 'base64'

module Announcer
  module Mixins
    module Serializable
      MAGIC = :SRLZ
      VERSION = 1

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def serialize_with(*args)
          _serializable_values[:args] = args.map(&:to_sym)
        end

        def deserialize(encoded)
          marshalled = _serializable_decode(encoded)
          package = _serializable_unmarshal(marshalled)
          _serializable_load_package(package)
        end

        def _serializable_load_package(package)
          klass, args = _serializable_unpackage(package)
          klass._deserialize_args(args)
        end

        def _deserialize_args(args)
          args = args.map { |arg| _deserialize_arg(arg) }

          if respond_to?(:load_from_serialized)
            load_from_serialized(*args)
          else
            new(*args)
          end
        end

        def _deserialize_arg(arg)
          if _serializable_valid_package?(arg, false)
            _serializable_load_package(arg)
          else
            arg
          end
        end

        ###
        # Encoding
        ###
        def _serializable_encode(marshalled)
          Base64.strict_encode64(marshalled) # => encoded
        end

        def _serializable_decode(encoded)
          begin
            Base64.strict_decode64(encoded) # => marshalled
          rescue ArgumentError
            raise Errors::SerializableError, 'serialized string not encoded properly'
          end
        end

        ###
        # Marshalling
        ###
        def _serializable_marshal(package)
          Marshal.dump(package) # => marshalled
        end

        def _serializable_unmarshal(marshalled)
          begin
            Marshal.load(marshalled) # => package
          rescue TypeError
            raise Errors::SerializableError, 'incorrect format'
          end
        end

        ###
        # Class Encoding
        ###

        def _serializable_encode_class(klass)
          klass.name.to_s.sub('Announcer::', '').to_sym
        end

        def _serializable_decode_class(encoded_klass)
          Announcer.const_get(encoded_klass.to_s)
        end

        ###
        # Packaging
        ###
        def _serializable_package(klass, args)
          encoded_klass = _serializable_encode_class(klass)
          [MAGIC, VERSION, encoded_klass] + args # => package
        end

        def _serializable_valid_package?(package, noisy=true)
          unless package.is_a?(Array)
            if noisy
              raise Errors::SerializableError, 'not a package'
            else
              return false
            end
          end

          magic, version, class_name = package

          # Check Magic
          unless magic == MAGIC
            if noisy
              raise Errors::SerializableError, 'invalid serialized package'
            else
              return false
            end
          end

          # Check Version
          unless version == VERSION
            if noisy
              raise Errors::SerializableError, 'unsupported package version'
            else
              return false
            end
          end

          # Check Class Name
          unless class_name.is_a?(Symbol)
            if noisy
              raise Errors::SerializableError, 'invalid class name'
            else
              return false
            end
          end

          return true
        end

        def _serializable_unpackage(package)
          _serializable_valid_package?(package)
          magic, version, encoded_klass, *args = package
          klass = _serializable_decode_class(encoded_klass)
          [klass, args]
        end

        ###
        # Helpers
        ###
        def _serializable_values
          @__serializable_values ||= {}
        end

        def _serializable_args
          _serializable_values[:args] or
            raise Errors::SerializableError, "Missing serialize_with definition"
        end
      end

      def serialize
        package = _serializable_package
        marshalled = self.class._serializable_marshal(package)
        self.class._serializable_encode(marshalled)
      end

      def _serializable_package
        args = _serializable_args.map { |arg| _serialize_arg(send(arg)) }
        self.class._serializable_package(self.class, args)
      end

      def _serialize_arg(arg)
        case arg
        when Serializable
          arg._serializable_package
        else
          arg
        end
      end

      def _serializable_args
        self.class._serializable_args
      end
    end
  end
end
