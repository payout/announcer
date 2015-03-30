require 'resque'
require 'securerandom'

module Ribbon::EventBus
  module Plugins
    RSpec.describe LoggingPlugin do
      let(:instance) { Instance.new("logging_plugin_test_#{SecureRandom.hex}") }
      let(:config) { instance.config }
      let(:event) { :test }

      before { instance.plugin :logging }

      context 'with resque publisher' do
        # Configure to publish to resque publisher
        before { instance.config { publish_to :resque } }
        before { instance.subscribe_to(:test, name: 'testing') {} }
        before(:all) { Resque.inline = true }
        after(:all) { Resque.inline = false }

        context 'with default logger' do
          before { instance.config.plugins.logging.logger = nil } # Ensure it loads default logger
          subject { instance.publish(event) }

          context 'with invalid level' do
            before { instance.config.plugins.logging.level = :invalid_value }

            it 'should raise error' do
              expect { subject }.to raise_error(
                Errors::PluginError, "Invalid plugins.logging.level: :invalid_value"
              )
            end
          end # with invalid level

          context 'with valid level' do
            it 'should accept nil' do
              instance.config.plugins.logging.level = nil
              expect { subject }.not_to raise_error
            end

            it 'should accept :info' do
              instance.config.plugins.logging.level = :info
              expect { subject }.not_to raise_error
            end

            it 'should accept :warn' do
              instance.config.plugins.logging.level = :warn
              expect { subject }.not_to raise_error
            end

            it 'should accept :error' do
              instance.config.plugins.logging.level = :error
              expect { subject }.not_to raise_error
            end

            it 'should accept :fatal' do
              instance.config.plugins.logging.level = :fatal
              expect { subject }.not_to raise_error
            end
          end
        end # with default logger

        context 'with custom logger' do
          let(:logger) { double('logger') }
          before { allow(logger).to receive(:debug) }

          subject { logger }
          before { config.plugins.logging.logger = logger }

          context 'without exception' do
            after { instance.publish(event) }
            it { is_expected.to receive(:debug).with("Publishing: Event(test)").once }
            it { is_expected.to receive(:debug).with("Finished Publishing: Event(test)").once }
            it { is_expected.to receive(:debug).with("Publishing on Resque: Event(test)").once }
            it { is_expected.to receive(:debug).with("Finished Publishing on Resque: Event(test)").once }
            it { is_expected.to receive(:debug)
              .with("Executing Subscription: Subscription(on test: testing)").once }
            it { is_expected.to receive(:debug)
              .with("Finished Executing Subscription: Subscription(on test: testing)").once }
          end # without exception

          context 'with exception' do
            # This will trigger an error in Event#publish when it tries to call
            # ResquePublihser#publish
            before { allow(instance.publishers.first).to receive(:publish).and_raise("error") }

            after { expect { instance.publish(event) }.to raise_error("error") }

            context 'without log_exceptions enabled' do
              it { is_expected.to receive(:debug).with("Publishing: Event(test)").once }
              it { is_expected.not_to receive(:debug).with("Finished Publishing: Event(test)") }
            end # without log_exceptions enabled

            context 'with log_exceptions enabled' do
              before { allow(logger).to receive(:fatal) }
              before { instance.config.plugins.logging.log_exceptions = true }

              it { is_expected.to receive(:debug).with("Publishing: Event(test)").once }
              it { is_expected.not_to receive(:debug).with("Finished Publishing: Event(test)") }
              it { is_expected.to receive(:fatal).with(
                'Exception raised when publishing Event(test): #<RuntimeError: error>'
                ).once }
            end # with log_exceptions enabled
          end # with exception
        end # with custom logger
      end # with resque publisher
    end # LoggingPlugin
  end # Plugins
end # Ribbon::EventBus