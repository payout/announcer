require 'securerandom'

module Ribbon::EventBus
  RSpec.describe Instance do
    it 'should raise error on duplicate instance names' do
      Instance.new(:test_duplicate_name)
      expect { Instance.new(:test_duplicate_name) }.to raise_error(
        Errors::DuplicateInstanceNameError, 'test_duplicate_name'
      )
    end

    it 'should convert name to symbol' do
      name = SecureRandom.hex
      expect(Instance.new(name).name).to eq name.to_sym
    end

    let(:instance) { Instance.new }
    subject { instance }

    context '#config' do
      it 'should raise error for invalid publisher name' do
        expect {
          subject.config { |c| c.publish_to :non_existent_publisher }
        }.to raise_error(
          Errors::InvalidPublisherNameError, 'non_existent_publisher'
        )
      end

      it 'should raise error for invalid publisher class' do
        expect {
          subject.config { |c| c.publish_to Class.new }
        }.to raise_error(
          Errors::InvalidPublisherError
        )
      end

      it 'should raise error for blocks with invalid arity' do
        expect {
          subject.config { |c| c.publish_to {} }
        }.to raise_error(
          Errors::InvalidArityError, 'Proc arity must be 1'
        )
      end
    end

    context '#publish' do
      it 'should raise error if no publishers defined' do
        expect { subject.publish(:name) }.to raise_error(Errors::NoPublishersDefinedError)
      end

      it 'should raise error when passing invalid params' do
        subject.config { publish_to :subscriptions }
        expect { subject.publish(:name, 1234) }.to raise_error(
          ArgumentError, 'event parameters must be a hash'
        )
      end

      it 'should run publishers' do
        event_received = nil
        subject.config { |c| c.publish_to { |e| event_received = e.name } }
        subject.publish(:test_event)
        expect(event_received).to eq :test_event
      end

      it 'should work with subscriptions publisher' do
        subject.config { |c| c.publish_to :subscriptions }

        subscription_executed = false
        subject.subscribe_to(:test) { |e| subscription_executed = true }

        subject.publish(:test)

        expect(subscription_executed).to be true
      end
    end

    context '#subscribe_to' do
      it 'should order subscriptions based on priority' do
        subject.config.subscriptions.max_priority = 9
        subject.subscribe_to(:test_event, name: 1, priority: 7) { |e| 7 }
        subject.subscribe_to(:test_event, name: 2, priority: 1) { |e| 1 }
        subject.subscribe_to(:test_event, name: 3, priority: 3) { |e| 3 }
        subject.subscribe_to(:test_event, name: 4, priority: 2) { |e| 2 }
        subject.subscribe_to(:test_event, name: 5, priority: 2) { |e| 2 }
        subject.subscribe_to(:test_event, name: 6, priority: 9) { |e| 9 }
        subject.subscribe_to(:test_event, name: 7, priority: 8) { |e| 8 }

        event = Event.new(:test_event, instance: subject)

        expect(subject.subscriptions_to(:test_event).map { |s| s.handle(event) })
          .to eq([1, 2, 2, 3, 7, 8, 9])
      end

      it 'should return subscription' do
        expect(subject.subscribe_to(:test_event)).to be_a Subscription
      end
    end

    context '#serialize', :serialize do
      # Need to generate a random instance name since it's stored globally.
      # It needs to be unique for each test.
      subject { EventBus.instance("serialize_test_#{SecureRandom.hex}".to_sym) }

      let(:serialized) { subject.serialize }
      let(:deserialized) { Instance.deserialize(serialized) }

      before(:each) do
        subject.subscribe_to(:one) { |e| }
        subject.subscribe_to(:two, name: 'first') { |e| }
        subject.subscribe_to(:two, name: 'second') { |e| }
      end

      it 'should be the same object' do
        # This is when it's in the same process.
        expect(deserialized.object_id).to eq subject.object_id
      end

      it 'should preserve subscriptions' do
        # A bit unnecessary considering the above test. But it's nice to know
        # that the serialization process doesn't affect subscriptions.
        expect(subject.subscriptions_to(:one).length).to eq 1
        expect(deserialized.subscriptions_to(:one).length).to eq 1

        expect(subject.subscriptions_to(:two).length).to eq 2
        expect(deserialized.subscriptions_to(:two).length).to eq 2
      end

      it 'should raise error when deserializing unnamed instance' do
        expect { Instance.deserialize(Instance.new.serialize) }.to raise_error(
          Errors::InstanceError, "Can't deserialize an unnamed Instance"
        )
      end
    end

    context '#_register_subscription' do
      let(:subscription) { instance.subscribe_to(:event) }

      it 'raises error on duplicate subscription identifier' do
        expect { instance._register_subscription(subscription) }.to raise_error(
          Errors::SubscriptionError, /^duplicate identifier:/
        )
      end
    end
  end
end