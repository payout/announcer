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

      before(:each) do
        instance.config { |c| c.publish_to :resque }
        instance.subscribe_to(:test, priority: 1) { |e| @subscriptions_run = true }
      end

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
          instance.config.publishers.resque.subscription_queue_format = 'test_%{priority}_%{event}'
          instance.publish(event)
          expect(queue).to eq :test_1_test
        end

        it 'should support setting per publisher queues' do
          instance.config { |c|
            c.publish_to :resque, subscription_queue_format: 'custom_%{priority}'
          }

          instance.publish(event)
          expect(queues).to eq [:subscriptions_p1, :custom_1]
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
    end
  end
end