module Ribbon::EventBus
  RSpec.describe Subscription do
    let(:event_name) { :name }
    let(:params) { Hash.new }
    subject { Subscription.new(event_name, params.merge(instance: Instance.new))}

    context 'with string event name' do
      let(:event_name) { 'name' }

      it 'should convert event_name to symbol' do
        expect(subject.event_name).to eq :name
      end
    end

    describe 'priority' do
      let(:params) { { priority: priority } }

      context 'integer priority' do
        let(:priority) { 1 }
        it { is_expected.to have_attributes(priority: 1) }
      end

      context 'default priority' do
        let(:priority) { nil }
        it { is_expected.to have_attributes(priority: 3) }
      end

      context 'symbol priority' do
        let(:priority) { :low }
        it { is_expected.to have_attributes(priority: 4) }
      end

      context 'string priority' do
        let(:priority) { 'highest' }
        it { is_expected.to have_attributes(priority: 1) }
      end

      context 'invalid symbol priority' do
        let(:priority) { :bad }
        it { expect { subject }.to raise_error(Errors::InvalidPriorityError, ':bad') }
      end

      context 'invalid string priority' do
        let(:priority) { 'bad' }
        it { expect { subject }.to raise_error(Errors::InvalidPriorityError, ':bad') }
      end

      context 'with integer priority below range' do
        let(:priority) { 0 }
        it { expect { subject }.to raise_error(Errors::InvalidPriorityError, '0') }
      end

      context 'with integer priority above range' do
        let(:priority) { 6 }
        it { expect { subject }.to raise_error(Errors::InvalidPriorityError, '6') }
      end

      context 'with floating-point priority' do
        let(:priority) { 5.5 }
        it { expect { subject }.to raise_error(Errors::InvalidPriorityError, '5.5') }
      end
    end # priority

    describe 'subscription name' do
      let(:params) { { name: 'subscription name' } }

      it 'can be defined' do
        is_expected.to have_attributes(name: 'subscription name')
      end
    end # subscription name

    describe 'identifier' do
      it 'raises error for duplicate identifers' do
        expect { Subscription.new(event_name, instance: subject.instance) }. to(
          raise_error(Errors::DuplicateIdentifierError, "give this subscription a unique name")
        )
      end
    end # identifier
  end
end
