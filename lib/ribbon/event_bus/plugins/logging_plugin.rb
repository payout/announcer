require 'logger'

module Ribbon::EventBus
  module Plugins
    class LoggingPlugin < Plugin
      config_key :logging

      def logger
        @_logger ||= _load_logger
      end

      around_publish do |event|
        logger.debug("Publishing #{event}")
        _run(subject: 'publishing', object: event) { publish }
        logger.debug("Published #{event}")
      end

      around_resque_publish do |event|
        logger.debug("Publishing on Resque: #{event}")
        _run(subject: 'publishing on resque', object: event) { resque_publish }
        logger.debug("Published on Resque: #{event}")
      end

      around_subscription do |sub, event|
        logger.debug("Executing subscription: #{sub}")
        _run(subject: 'executing subscription', object: sub) { subscription }
        logger.debug("Executed subscription: #{sub}")
      end

      private
      def _load_logger
        if config.logger?
          config.logger
        else
          Logger.new(STDOUT).tap { |logger|
            logger.level = _load_level
          }
        end
      end

      def _load_level
        case config.level
        when :info, nil
          Logger::INFO
        when :warn
          Logger::WARN
        when :error
          Logger::ERROR
        when :fatal
          Logger::FATAL
        else
          raise Errors::PluginError, "Invalid plugins.logging.level: #{config.level.inspect}"
        end
      end

      def _run(params={}, &block)
        if config.log_exceptions?
          begin
            block.call
          rescue Exception => e
            logger.fatal("Exception raised when %{subject} %{object}: #{e.inspect}" % params)
            raise
          end
        else
          block.call
        end
      end
    end
  end
end