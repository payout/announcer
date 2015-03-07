[![Gem Version](https://badge.fury.io/rb/ribbon-event_bus.svg)](http://badge.fury.io/rb/ribbon-event_bus) [![Code Climate](https://codeclimate.com/github/ribbon/event_bus/badges/gpa.svg)](https://codeclimate.com/github/ribbon/event_bus) [![Test Coverage](https://codeclimate.com/github/ribbon/event_bus/badges/coverage.svg)](https://codeclimate.com/github/ribbon/event_bus) [![Build Status](https://semaphoreapp.com/api/v1/projects/bb850102-b137-432b-9cbe-e1824ef4013f/365383/shields_badge.svg)](https://semaphoreapp.com/ribbon/event_bus)

# ribbon-event_bus

A simple but flexible event bus for Ruby. With the recommended settings, it
processes event subscriptions on Resque asynchronously. Each event subscription
is also processed as a separate Resque job. This allows subscriptions to be
executed with different priorities (i.e., in different queues).

It is also possible to publish events to other Redis servers to be processed by
other event buses. This is useful when using a multi-service architecture, where
several Rails apps can subscribe to each others events.

## Installation

Add this to your Gemfile:

```
gem 'ribbon-event_bus'
```

Then run

```
bundle
```

Or you can install it manually:

```
gem install ribbon-event_bus
```

## Basic Usage

### Configuration

Below is an example of configuring the event bus.

```Ruby
# config/initializers/event_bus.rb
EventBus.config do
  publish_to :resque
end
```
This is all that is needed if Resque is already configured in your app. This will expect Resque to listen to the following queues: `publisher`, `subscriptions_p1`, `subscriptions_p2`, `subscriptions_p3`, ..., `subscriptions_p10`. Here the `p#` refers to the subscription priority. You must configure Resque to evaluate these queues in the expected order.

### Subscriptions

Define subscriptions in initializers.

For example:
```Ruby
# config/initializers/event_bus/image_processing_subcriptions.rb

EventBus.subscribe_to(:image_uploaded, priority: 1) do |event|
  Image.find(event[:image_id]).process
end

EventBus.subscribe_to(:image_processed, priority: :medium) do |event|
  Image.find(event[:image_id]).send_important_email
end
```

#### Priorities
Each subscription has a priority, which affects the order in which it
is published to. By default, subscriptions have a priority of `5`.
When using the ResquePublisher, this also effects which Resque
queue they are placed in. This allows you to configure Resque to run some
subscriptions with higher priority.

There are 10 available priorities (1 through 10).

The following human readable shortcuts are also available:

shortcut | priority
---------|---------
highest  | 1
high     | 3
medium   | 5
low      | 7
lowest   | 10


### Events

To publish events, simply call the #publish method.

```Ruby
image = Image.create
EventBus.publish(:image_uploaded, image_id: image.id)
```

## Details

### Instances

It's possible to have multiple EventBus instances, although this is not necessary for
most use-cases.

For example:
```ruby
# Note: instance names must be globally unique!
synchronous_bus = EventBus.instance("a synchronous event bus")
synchronous_bus.config { |c| c.publish_to :subscriptions }
synchronous_bus.subscribe_to(:an_event) { |event| raise event.inspect }
synchronous_bus.publish(:an_event)
```

This example publishes directly to the subscriptions (i.e., synchronously), but
publishing to resque is also supported with multiple instances, and events
published on one instance won't be sent to subscriptions on other instances!

### Publishers

There are currently 4 supported publishers. One of which allows you to define an
arbitrary block to execute. Note that a publisher doesn't have to submit the event to
the subscriptions. It can, for example, simply output the event to a log.

It is possible to define multiple publishers for an event bus. They will all be
called synchronously with the #publish method.

For all publishers, you can define global config values in the `EventBus.config`
block. Values defined here will apply to all instances of the respective publisher.

You can also specify per publisher configuration values when calling `publish_to`
in the config block. For example:
```ruby
EventBus.config do
  publish_to :resque, publisher_queue: 'another_queue'
  publish_to :remote_resque, redis: Redis.new(url: 'server1')
  publish_to :remote_resque, redis: Redis.new(url: 'server2')
end
```
Now if an event is published, the `ResquePublisher` will publish on the 'another_queue'
queue and the two instances of `RemoteResquePublisher` will publish the same event
to separate Redis servers.


#### subscriptions
A simple, synchronous publisher. If you configure your event bus to use this publisher,
your subscriptions will be executed in line with your call to `#publish`. Although not
ideal for production use, this publisher can be helpful when debugging event bus
issues.

##### Config
No unique configuration

#### resque
Publishes to the subscriptions on two phases:
  1. Enqueues a publisher Resque job (default queue: `publisher`)
  2. The publisher job enqueues a subscription Resque job for each subscription (default queue: `subscription_p%{priority}`). Each subscription is executed as a separate Resque job.

##### Config

Key | Default | Description
----|---------|------------
publishers.resque.**publisher_queue** | `'publisher'` | Configure the Resque queue used for publishing events.
publishers.resque.**subscription_queue_format** | `'subscriptions_p%{priority}'` | Configure the queue used for subscriptions. Other than 'priority', you may also reference the event name with 'event'.

#### remote_resque
Publishes events to a Resque queue on a separate Redis server. This allows you to
publish events from one service to another.

##### Config

Key | Default | Description
----|---------|------------
publishers.remote_resque.**redis** | `nil` | Can be a Redis or Redis::Namespace object.
publishers.remote_resque.**redis_url** | `nil` | A redis url (e.g., `redis://server:1234`)
publishers.remote_resque.**redis_namespace** | `resque` | The namespace to use.
publishers.remote_resque.**queue** | `'publisher'` | The queue on the redis server to submit the publisher job to.
publishers.remote_resque.**subscription_queue_format** | `'subscriptions_p%{priority}'` |

#### Custom Blocks
You can also specify custom blocks as publishers:
```ruby
EventBus.config do
  publish_to do |event|
    puts "An event has occurred: #{event.name} #{event.params}"
  end
end
```
Be careful not to do anything too time consuming, as all publishers are executed
synchronously when you publish an event.

### Plugins
EventBus uses the [ribbon/plugins](https://github.com/ribbon/plugins) gem and currently supports the following hooks:
 * publish
 * resque_publish
 * subscription

You can enable plugins via the config block:
```ruby
EventBus.config {
  plugin :plugin_name, additional_args: 'go here'
}
```

Or outside a config block via the `Instance#plugin` method:
```ruby
EventBus.plugin(:plugin_name, additional_args: 'go here')
```

There is currently one built-in plugin: `:logging`.
#### Logging
```ruby
EventBus.config {
  # Default options shown here.
  plugin :logging, logger: Logger.new(STDOUT), level: :info, log_exceptions: false
}
```

When this plugin is enabled, debug messages will be logged before and after each of the above listed hooks. If log_exceptions is enabled, then the plugin will catch, log and reraise any exceptions.

#### Custom Plugins
You can also add your own custom plugins:
```ruby
EventBus.config {
  plugin {
    before_publish do |event|
      # Do something
    end
  
    before_resque_publish do |event|
      # Do something
    end
  
    before_subscription do |subscription, event|
      # Do something
    end
  }
}
```
See [ribbon/plugins](https://github.com/ribbon/plugins) for more details on defining plugins.
