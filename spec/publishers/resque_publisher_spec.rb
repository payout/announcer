require 'securerandom'

module Ribbon::EventBus
  module Publishers
    RSpec.describe ResquePublisher do
      before(:all) do
        Resque.inline = true
      end

      after(:all) do
        Resque.inline = false
      end

      let(:instance) { EventBus.instance("resque_test_#{SecureRandom.hex}") }
      let(:event) { Event.new(:test, instance: instance) }
      let(:subscription) { instance.subscribe_to(:test, priority: 1) { |e| @subscriptions_run = true } }

      before(:each) do
        instance.config { |c| c.publish_to :resque }
        subscription
      end

      let(:publisher) { instance.find_publisher(:resque) }

      it 'should run subscriptions' do
        expect(@subscriptions_run).to be nil
        instance.publish(event)
        expect(@subscriptions_run).to eq true
      end

      context 'publisher queue' do
        before(:each) do
          @queue = nil

          allow(ResquePublisher::PublisherJob).to receive(:set_queue) { |q|
            @queue = q
          }
        end

        let(:queue) { @queue }

        it 'should use default queue' do
          instance.publish(event)
          expect(queue).to eq :publisher
        end
      end

      context 'subscription queue' do
        before(:each) do
          @queues = []

          allow(ResquePublisher::SubscriptionJob).to receive(:set_queue) { |q|
            @queues << q
          }
        end

        let(:queues) { @queues }
        let(:queue) { queues.last }

        it 'should use default format' do
          instance.publish(event)
          expect(queue).to eq :subscriptions_p1
        end

        it 'should support changing format' do
          instance.config.publishers.resque.subscription_queue_formatter {|s| "test_#{s.priority}_test"}
          instance.publish(event)
          expect(queue).to eq :test_1_test
        end

        it 'should support setting per publisher queues' do
          # Need to clear previous ResquePublisher from publishers:
          instance.config { |c| c.publish_to = nil }

          # Add new ResquePublisher
          instance.config {
            publish_to :resque, subscription_queue_formatter: lambda {|s| "custom_#{s.priority}"}
          }

          instance.publish(event)
          expect(queues).to eq [:custom_1]
        end
      end

      it 'should raise error when receiving event from wrong instance' do
        other_instance = Instance.new
        other_event = Event.new(:test, instance: other_instance)

        publishers = instance.publishers
        expect(publishers.count).to eq 1
        publisher = publishers.first

        expect { publisher.publish(other_event) }.to raise_error(
          Errors::PublisherError, "Event for different instance"
        )
      end

      describe '#subscription_queue_formatter' do
        before { publisher.config.subscription_queue_formatter = formatter }
        subject { publisher.subscription_queue_formatter.call(subscription) }

        context 'with undefined config value' do
          let(:formatter) { nil }
          it { is_expected.to eq "subscriptions_p#{subscription.priority}" }
        end # with default config

        context 'with lambda config value' do
          let(:formatter) { lambda {|s| "lambda_#{s.priority}"} }
          it { is_expected.to eq "lambda_#{subscription.priority}" }
        end # with lambda config value

        context 'when using config proc add syntax' do
          let(:formatter) { nil }
          before { publisher.config.subscription_queue_formatter {|s| s.priority.to_s } }
          it { is_expected.to eq subscription.priority.to_s }

          context 'with multiple procs added' do
            before { 3.times { |i| publisher.config.subscription_queue_formatter {|s| i + 1} } }
            it { is_expected.to eq 3 }
          end # with multiple procs added
        end # when using config proc add syntax

        context 'when using unexpected value' do
          let(:formatter) { Class.new }
          it { expect { subject }.to raise_error(Errors::PublisherError, /^Invalid subscription_queue_formatter/) }
        end
      end # #subscription_queue_formatter
    end
  end
end