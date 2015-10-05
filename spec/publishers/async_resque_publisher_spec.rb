require 'securerandom'
require 'redis'

module Announcer
  module Publishers
    RSpec.describe AsyncResquePublisher do
      before(:all) do
        Resque.inline = true
      end

      after(:all) do
        Resque.inline = false
      end

      around { |ex|
        Celluloid.shutdown
        Celluloid.boot
        ex.run
      }

      let(:instance) { Announcer.instance("resque_test_#{SecureRandom.hex}") }
      let(:event) { Event.new(:test, instance: instance) }
      let(:subscription) { instance.subscribe_to(:test, priority: 1) { |e| @subscriptions_run = true } }
      let(:resque_mock) { nil }

      before(:each) do
        instance.config { |c| c.publish_to :async_resque, resque: resque_mock }
        subscription # preload the subscription
      end

      let(:publisher) { instance.find_publisher(:async_resque) }

      it 'should run subscriptions' do
        expect(@subscriptions_run).to be nil
        instance.publish(event)
        sleep(0.1) # Let the PublisherWorker thread run.
        expect(@subscriptions_run).to eq true
      end

      context 'subscription queue' do
        let(:resque_mock) { double('Resque') }

        it 'should use default format', :test do
          expect(resque_mock).to receive(:enqueue_to).with(
            :publisher,
            ResquePublisher::PublisherJob,
            String,
            :async_resque
          )

          instance.publish(event)
          sleep(0.01) # Let the PublisherWorker thread run.
        end

        it 'should support setting per publisher queues' do
          # Need to clear previous AsyncResquePublisher from publishers:
          instance.config { |c| c.publish_to = nil }

          # Add new AsyncResquePublisher
          instance.config { |c|
            c.publish_to :async_resque, resque: resque_mock,
              subscription_queue_formatter: lambda {|s| "custom_#{s.priority}"}
          }

          expect(resque_mock).to receive(:enqueue_to).with(
            :publisher,
            ResquePublisher::PublisherJob,
            String,
            :async_resque
          )

          instance.publish(event)
          sleep(0.01)
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

      context 'with exception raised when enqueueing' do
        let(:resque_mock) {
          double('Resque').tap { |resque|
            allow(resque).to receive(:enqueue_to) { raise exception }
          }
        }

        context 'with Redis::BaseConnectionError' do
          let(:exception) { Redis::BaseConnectionError }

          it 'should not kill publisher worker' do
            instance.publish(event)
            expect(publisher.worker.dead?).to be false
            sleep(0.01)
          end
        end
      end # with exception raised when enqueueing
    end
  end
end
