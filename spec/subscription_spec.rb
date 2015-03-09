module Ribbon::EventBus
  RSpec.describe Subscription do
    it 'should convert event_name to symbol' do
      expect(Subscription.new('name').event_name).to eq :name
    end

    context 'priority' do
      it 'supports integer priorities' do
        expect(Subscription.new(:name, priority: 1).priority).to eq 1
      end

      it 'has default priority' do
        EventBus.config { |c| c.subscriptions.default_priority = 3 }
        expect(Subscription.new(:name).priority).to eq 3
      end

      it 'supports symbol priorities' do
        expect(Subscription.new(:name, priority: :medium).priority).to eq 3
      end

      it 'supports string priorities' do
        expect(Subscription.new(:name, priority: 'highest').priority).to eq 1
      end

      it 'raises error for invalid priorities' do
        expect { Subscription.new(:name, priority: :bad) }.to raise_error(
          Errors::InvalidPriorityError, ':bad'
        )

        expect { Subscription.new(:name, priority: 'bad') }.to raise_error(
          Errors::InvalidPriorityError, ':bad'
        )

        expect { Subscription.new(:name, priority: 0) }.to raise_error(
          Errors::InvalidPriorityError, '0'
        )

        expect { Subscription.new(:name, priority: 11) }.to raise_error(
          Errors::InvalidPriorityError, '11'
        )

        expect { Subscription.new(:name, priority: 5.5) }.to raise_error(
          Errors::InvalidPriorityError, '5.5'
        )
      end

      it 'allows subscription name to be defined' do
        expect(Subscription.new(:event, name: 'subscription name').name)
          .to eq 'subscription name'
      end

      it 'raises error for duplicate locators' do
        sub = Subscription.new(:name)
        expect { sub.instance._register_subscription(sub) }.to raise_error(
          Errors::SubscriptionError, /^duplicate locator:/
        )
      end
    end
  end
end
