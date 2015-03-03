require 'securerandom'
require 'resque'
require 'mock_redis'

module Ribbon::EventBus
  module Publishers
    RSpec.describe RemoteResquePublisher do
      let(:instance) { EventBus.instance("remote_resque_test_#{SecureRandom.hex}") }
      let(:event) { Event.new(:test, instance: instance) }

      before(:all) { Resque.inline = true }
      after(:all) { Resque.inline = false }

      before(:each) do
        instance.config { |c| c.publish_to :remote_resque, redis: redis }
        instance.subscribe_to(:test) { |e| @subscription_ran = true }
      end

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

      context 'with redis' do
        let(:redis) { MockRedis.new }

        it 'should enqueue publisher job' do
          instance.publish(event)
          job = reserve('publisher')

          expect(@subscription_ran).to be nil

          expect(job.payload_class).to be ResquePublisher::PublisherJob
          expect(job.perform).to be true
          expect(@subscription_ran).to be true
        end

        it 'should use configured queue' do
          instance.config.publishers.remote_resque.queue = 'testing'
          instance.publish(event)
          expect(reserve('testing')).to be_a Resque::Job
        end
      end

      context 'when redis not defined' do
        let(:redis) { nil }
        it 'should raise error' do
          expect { instance.publish(event) }.to raise_error(
            Errors::RemoteResquePublisherError, "missing redis configuration"
          )
        end
      end
    end
  end
end