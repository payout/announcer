require 'securerandom'
require 'resque'
require 'mock_redis'

module Ribbon::EventBus
  module Publishers
    RSpec.describe RemoteResquePublisher do
      ###
      # Simulating Resque v1.25.2 behavior
      #
      # Worker call stack:
      #  -> Resque.reserve(queue)
      #  -> Job.reserve(queue)
      #  -> Resque.pop(queue)
      #  -> Job.new(queue, payload)
      ###

      # Job.reserve(queue)
      def reserve(queue)
        if (payload = pop(queue))
          Resque::Job.new(queue, payload)
        end
      end

      # Resque.pop(queue)
      def pop(queue)
        decode redis.lpop("queue:#{queue}")
      end

      def decode(object)
        Resque.decode(object)
      end

      ###
      # Begin test code
      ###
      before(:all) { Resque.inline = true }
      after(:all) { Resque.inline = false }

      let(:instance) { EventBus.instance("remote_resque_test_#{SecureRandom.hex}") }
      let(:event) { Event.new(:test, instance: instance) }
      let(:subscription) { instance.subscribe_to(:test) {} }

      before do
        instance.config { |c| c.publish_to :remote_resque, redis: redis }
        subscription
      end

      describe '#publish' do
        let(:remote_resque) { instance.find_publisher(:remote_resque) }
        subject { remote_resque.publish(event) }
        let(:job) { subject; reserve(remote_resque.config.queue) }

        context 'when redis not defined' do
          let(:redis) { nil }

          it 'should raise error' do
            expect { subject }.to raise_error(
              Errors::RemoteResquePublisherError, "missing redis configuration"
            )
          end
        end # when redis not defined

        context 'with redis' do
          let(:redis) { MockRedis.new }

          context 'non-default publisher queue' do
            before { remote_resque.config.queue = 'testing' }

            it 'should use configured queue' do
              subject
              expect(reserve('testing')).to be_a Resque::Job
            end

            it 'should enqueue publisher job' do
              expect(job.payload_class).to be ResquePublisher::PublisherJob
            end
          end # non-default publisher queue

          context 'with default publisher queue' do
            it 'should use default queue' do
              subject
              expect(reserve('publisher')).to be_a Resque::Job
            end

            it 'should enqueue publisher job' do
              expect(job.payload_class).to be ResquePublisher::PublisherJob
            end
          end # with default publisher queue
        end # with redis
      end # #publish

      describe 'Job#perform' do
        let(:redis) { MockRedis.new }
        let(:remote_resque) { instance.find_publisher(:remote_resque) }
        let(:job) { remote_resque.publish(event); reserve(remote_resque.config.queue) }
        subject { job.perform }

        context 'without destination ResquePublisher' do
          it 'should raise exception' do
            expect { subject }.to raise_error(
              Errors::PublisherError, 'No ResquePublisher found'
            )
          end
        end # without destination ResquePublisher

        context 'with destination ResquePublisher' do
          before { instance.config { publish_to :resque } }
          it { is_expected.to be true }

          it 'should execute subscription' do
            expect(subscription).to receive(:handle).once
            subject
          end
        end # with destination ResquePublisher
      end # Job#perform
    end
  end
end