require 'securerandom'

module Announcer
  module Mixins
    class Nestable
      include Serializable
      serialize_with :value, :nested
      attr_reader :value, :nested
      def initialize(value, nested=nil)
        @value = value
        @nested = nested
      end
    end

    RSpec.describe Serializable do
      subject { Class.new.include Serializable }
      let(:bytes) { SecureRandom.random_bytes }

      context 'encoding' do
        it 'should by symmetric' do
          encoded = subject._serializable_encode(bytes)
          decoded = subject._serializable_decode(encoded)
          expect(decoded.bytes).to eq bytes.bytes
        end

        context '#_serializable_decode' do
          it 'should raise error when invalid base64' do
            expect { subject._serializable_decode('INVALID VALUE!') }.to raise_error(
              Errors::SerializableError, 'serialized string not encoded properly'
            )
          end
        end
      end

      context 'marshalling' do
        it 'should be symmentric' do
          marshalled = subject._serializable_marshal(bytes)
          unmarshalled = subject._serializable_unmarshal(marshalled)
          expect(unmarshalled.bytes).to eq bytes.bytes
        end

        context '#_serializable_unmarshal' do
          it 'should raise error when invalid marshaled data' do
            expect { subject._serializable_unmarshal('BAD MARSHAL') }.to raise_error(
              Errors::SerializableError, 'incorrect format'
            )
          end
        end
      end

      context 'packaging' do
        let(:klass) { Serializable }
        let(:args) { [1, 'two', :three] }
        it 'should be symmentric' do
          package = subject._serializable_package(klass, args)
          unpackaged = subject._serializable_unpackage(package)
          expect(unpackaged).to eq [klass, args]
        end

        it 'should produce valid package' do
          package = subject._serializable_package(klass, args)
          expect(subject._serializable_valid_package?(package)).to be true
        end

        context '#_serializable_unpackage' do
          it "should raise error when package isn't an array" do
            expect { subject._serializable_unpackage('not_array') }.to raise_error(
              Errors::SerializableError, 'not a package'
            )
          end

          it 'should raise error when invalid package magic' do
            bad_package = [:BAD_MAGIC, 1, :Class]
            expect { subject._serializable_unpackage(bad_package) }.to raise_error(
              Errors::SerializableError, 'invalid serialized package'
            )
          end

          it 'should raise error when invalid package version' do
            bad_package = [Serializable::MAGIC, 'bad version', :Class]
            expect { subject._serializable_unpackage(bad_package) }.to raise_error(
              Errors::SerializableError, 'unsupported package version'
            )
          end

          it 'should raise error when bad class name' do
            bad_package = [Serializable::MAGIC, 1, 'NotSymbol']
            expect { subject._serializable_unpackage(bad_package) }.to raise_error(
              Errors::SerializableError, 'invalid class name'
            )
          end
        end
      end

      context 'serializing' do
        it 'should raise error when serialize_with not defined' do
          expect { subject.new.serialize }.to raise_error(
            Errors::SerializableError, "Missing serialize_with definition"
          )
        end

        context 'nesting' do
          let(:root) { Nestable.new('one', Nestable.new(:two, Nestable.new(3))) }
          let(:serialized) { root.serialize }
          let(:deserialized) { Nestable.deserialize(serialized) }

          it 'should preserve nested classes' do
            expect(deserialized).to be_a Nestable
            expect(deserialized.nested).to be_a Nestable
            expect(deserialized.nested.nested).to be_a Nestable
          end

          it 'should preserve values' do
            expect(deserialized.value).to eq 'one'
            expect(deserialized.nested.value).to eq :two
            expect(deserialized.nested.nested.value).to eq 3
          end
        end
      end
    end
  end
end
