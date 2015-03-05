module Ribbon::EventBus
  RSpec.describe Config do
    it 'should allow nested values' do
      c = Config.new { |c|
        c.key = 'value'
        c.level1.level2.level3.key = 'testing3'
      }

      expect(c.key).to eq 'value'
      expect(c.level1.level2.level3.key).to eq 'testing3'

      expect(c.level1.name). to eq 'level1'
      expect(c.level1.level2.name).to eq 'level1.level2'
      expect(c.level1.level2.level3.name).to eq 'level1.level2.level3'
    end

    it 'should allow setting nil values' do
      c = Config.new { namespace.key = nil }
      expect(c.namespace.key).to be_a NilClass
    end

    it 'should support block with 0 arity' do
      c = Config.new {
        namespace.key = 'value'
        array 1
        array 2
        array 3
      }

      expect(c.namespace.key).to eq 'value'
      expect(c.array).to eq [1,2,3]
    end

    it 'should raise error on block with incorrect arity' do
      expect { Config.new { |a,b| } }.to raise_error(
        Config::ConfigError, 'invalid config block arity'
      )
    end

    context '#dup' do
      # Need to define constant here to get around rspec quirks.
      OBJECT = Object.new

      let(:config) { Config.new { ns.key = OBJECT }.dup }

      def key
        config.ns.key
      end

      context 'key' do
        it 'should preserve object value' do
          expect(key).to eq OBJECT
        end

        it 'should be same object' do
          expect(key.object_id).to eq OBJECT.object_id
        end
      end
    end

    it 'should support adding blocks' do
      c = Config.new { |c|
        c.test_block { |arg| arg }
        c.test_block { |arg| 1 }
      }

      expect(c.test_block.call('testing 1234')).to eq ['testing 1234', 1]
    end

    it 'should support setting value without equal sign' do
      c = Config.new { |c| c.key 'value'; c.key 'value2' }
      expect(c.key).to eq ['value', 'value2']
    end

    it 'should support "?" tester' do
      c = Config.new{|c| c.a = 'a'; c.f = false; c.t = true}
      expect(c.a?).to be true
      expect(c.f?).to be false
      expect(c.t?).to be true
      expect(c.not_defined?).to be false
    end

    context 'nested value' do
      let(:config) { Config.new { |c| c.level1.level2.level3.key = 'testing3' } }

      it 'should be definable' do
        level2 = config.level1.level2
        expect(level2.level3.key).to eq 'testing3'
        level2.define { |c| c.level3.key = 'changed' }
        expect(level2.level3.key).to eq 'changed'
        expect(config.level1.level2.level3.key).to eq 'changed'
      end

      it 'should be dupable' do
        level2 = config.level1.level2.dup
        level2.define { |c| c.level3.key = 'changed' }
        expect(level2.level3.key).to eq 'changed'
        expect(config.level1.level2.level3.key).to eq 'testing3'
      end
    end
  end
end