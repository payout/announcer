require 'logger'

module Ribbon::EventBus
  module Plugins
    class LoggingPlugin < Plugin
      config_key :logging

      def logger
        @_logger ||= _load_logger
      end

      around_publish do |event|
        _run('Publishing', event) { publish }
      end

      around_resque_publish do |event|
        _run('Publishing on Resque', event) { resque_publish }
      end

      around_subscription do |sub, event|
        _run('Executing Subscription', sub) { subscription }
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

      def _run(subject, object, &block)
        logger.debug("#{subject}: #{object}")

        if config.log_exceptions?
          begin
            block.call
          rescue Exception => e
            logger.fatal("Exception raised when #{subject.downcase} #{object}: #{e.inspect}")
            raise
          end
        else
          block.call
        end

        logger.debug("Finished #{subject}: #{object}")
      end
    end
  end
end