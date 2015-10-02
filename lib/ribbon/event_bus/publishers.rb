module Ribbon::EventBus
  module Publishers
    autoload(:Publisher,
      'ribbon/event_bus/publishers/publisher')
    autoload(:ProcPublisher,
      'ribbon/event_bus/publishers/proc_publisher')
    autoload(:SubscriptionsPublisher,
      'ribbon/event_bus/publishers/subscriptions_publisher')
    autoload(:ResquePublisher,
      'ribbon/event_bus/publishers/resque_publisher')
    autoload(:RemoteResquePublisher,
      'ribbon/event_bus/publishers/remote_resque_publisher')
    autoload(:AsyncResquePublisher,
      'ribbon/event_bus/publishers/async_resque_publisher')

    module_function
    def load_for_instance(instance)
      config = instance.config
      config.publish_to? ? _load_for_instance(instance, config.publish_to) : []
    end

    def _load_for_instance(instance, publishers)
      publishers.map { |publisher| _load_with_args(publisher, instance) }
    end

    def _load_with_args(publisher, *args)
      case publisher
      when Array
        _load_with_args(publisher[0], *(args + publisher[1..-1]))
      else
        load(publisher).new(*args)
      end
    end

    def load(publisher)
      case publisher
      when String, Symbol then _load_from_string(publisher.to_s)
      when Proc           then _load_from_proc(publisher)
      when Publisher      then publisher
      else raise Errors::InvalidPublisherError, publisher.inspect
      end
    end

    def _load_from_string(publisher_name)
      const_get((publisher_name.split('_').map(&:capitalize) + ['Publisher']).join)
    rescue NameError
      raise Errors::InvalidPublisherNameError, publisher_name
    end

    def _load_from_proc(publisher_proc)
      ProcPublisher.new(&publisher_proc)
    end
  end
end
