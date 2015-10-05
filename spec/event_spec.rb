module Announcer
  RSpec.describe Event do
    it 'should convert name to symbol' do
      expect(Event.new('name').name).to eq :name
    end

    context '#serialize' do
      let(:instance) { Announcer.instance("serialize_test_#{SecureRandom.hex}") }
      let(:params) {
        {
          int: 1234,
          string: 'value',
          symbol: :value,
          bool_t: true,
          bool_f: false,
          float: 3.14159,
          hash: {
            key: 'value',
            array: [7,8,9]
          },
          array: [1,2,3]
        }
      }

      subject { Event.new(:event_name, params.merge(instance: instance)) }
      let(:serialized) { subject.serialize }
      let(:deserialized) { Event.deserialize(serialized) }

      it 'should be deserializable' do
        expect(deserialized.instance).to eq instance
        expect(deserialized.instance.name).to match /^serialize_test_/
        expect(deserialized.params).to eq subject.params
      end
    end

    context 'params' do
      let(:good) do
        Event.new(:name,
          'key' => 'value',
          nested: {
            'nested_key' => 'nested value'
          }
        )
      end

      it 'should convert keys to symbols' do
        expect(good.params[:key]).to eq 'value'
        expect(good.params[:nested][:nested_key]).to eq 'nested value'
      end

      it 'should support #[]' do
        expect(good[:key]).to eq 'value'
      end

      it 'should be sanitized' do
        expect {
          Event.new(:name, something: Proc.new{})
        }.to raise_error Errors::UnsafeValueError
      end

      it 'with nested array should be sanitized' do
        expect {
          Event.new(:name, array: ['good value', Proc.new{}])
        }.to raise_error Errors::UnsafeValueError, /^:array =>/
      end

      it 'with nested hash should be sanitized' do
        expect {
          Event.new(:name, hash: {good: 'value', bad: Proc.new{}})
        }.to raise_error Errors::UnsafeValueError, /^:bad =>/
      end
    end

    let(:instance) { Instance.new }
    let(:event) { Event.new(:test_event, instance: instance) }

    context '#subscriptions' do
      it 'should be populated from instance subscriptions' do
        expect(event.subscriptions.count).to eq 0
        instance.subscribe_to(event.name) { |e| }
        expect(event.subscriptions.count).to eq 1
      end
    end
  end
end
