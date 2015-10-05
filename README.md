[![Code Climate](https://codeclimate.com/github/payout/announcer/badges/gpa.svg)](https://codeclimate.com/github/payout/announcer) [![Test Coverage](https://codeclimate.com/github/payout/announcer/badges/coverage.svg)](https://codeclimate.com/github/payout/announcer) [![Build Status](https://semaphoreapp.com/api/v1/projects/bb850102-b137-432b-9cbe-e1824ef4013f/365383/shields_badge.svg)](https://semaphoreapp.com/payout/announcer) [![Inch CI](http://inch-ci.org/github/payout/announcer.png)](http://inch-ci.org/github/payout/announcer)

# Announcer

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
gem 'announcer'
```

Then run

```
bundle
```

Or you can install it manually:

```
gem install announcer
```

## Basic Usage

### Configuration

Below is an example of configuring the event bus.

```Ruby
# config/initializers/announcer.rb
Announcer.config do
  publish_to :resque
end
```

This is all that is needed if Resque is already configured in your app. This will expect Resque to listen to the following queues: `publisher`, `subscriptions_p1`, `subscriptions_p2`, ..., `subscriptions_p5`. Here the `p#` refers to the subscription priority. You must configure Resque to evaluate these queues in the expected order.

### Subscriptions

Define subscriptions in initializers.

For example:

```Ruby
# config/initializers/announcer/image_processing_subcriptions.rb

Announcer.subscribe_to(:image_uploaded, priority: 1) do |event|
  Image.find(event[:image_id]).process
end

Announcer.subscribe_to(:image_processed, priority: :medium) do |event|
  Image.find(event[:image_id]).send_important_email
end
```

#### Priorities
Each subscription has a priority assigned to it. By default, there are 5 priorities (1 through 5), 1 being the highest.
This affects the order in which subscriptions are published to. When using the ResquePublisher, this also affects which Resque queue they are placed in, allowing you to configure Resque to run some subscriptions with higher priority.

The following human readable shortcuts are also available:

shortcut | priority
---------|---------
highest  | 1
high     | 2
medium   | 3
low      | 4
lowest   | 5

By default, all subscriptions are given the `medium` priority, which is `3` in the default case.

If you'd like more, or less, priorities, you can set the `subscriptions.max_priority` config value. If you do so, the human readable shortcuts will dynamically conform to the new range, so they're safe to use.

```ruby
Announcer.config {
  subscriptions.max_priority = 3
}
```

new shortcut | priority
---|---
highest | 1
high    | 1
medium  | 2
low     | 3
lowest  | 3


### Events

To publish events, simply call the #publish method.

```Ruby
image = Image.create
Announcer.publish(:image_uploaded, image_id: image.id)
```

## Details

### Instances

It's possible to have multiple Announcer instances, although this is not necessary for
most use-cases.

For example:

```ruby
# Note: instance names must be globally unique!
synchronous_bus = Announcer.instance("a synchronous event bus")
synchronous_bus.config { |c| c.publish_to :subscriptions }
synchronous_bus.subscribe_to(:an_event) { |event| raise event.inspect }
synchronous_bus.publish(:an_event)
```

This example publishes directly to the subscriptions (i.e., synchronously), but
publishing to resque is also supported with multiple instances, and events
published on one instance won't be sent to subscriptions on other instances!

### Publishers

There are currently 5 supported publishers. One of which allows you to define an
arbitrary block to execute. Note that a publisher doesn't have to submit the event to
the subscriptions. It can, for example, simply output the event to a log.

It is possible to define multiple publishers for an event bus. They will all be
called synchronously with the #publish method.

For all publishers, you can define global config values in the `Announcer.config`
block. Values defined here will apply to all instances of the respective publisher.

You can also specify per publisher configuration values when calling `publish_to`
in the config block. For example:

```ruby
Announcer.config do
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
publishers.resque.**subscription_queue_formatter** | `lambda {|s| "subscriptions_p#{s.priority}"}` | A block taking a subscription as an argument and returning the queue to place it in. For example: `lambda {|s| [:high, :medium, :low][s.priority-1]}`

#### async_resque
Same as the above `resque` publisher, but enqueues to the publisher queue asynchronously (in a thread). This can be useful if you want to protect your app from temporary Redis failures, and you can accept a best-effort approach to publishing events. If publishing the event fails, no exception will be raised and your code will continue as before.

##### Config
Uses the same configuration as the `resque` publisher.

##### Unicorn Note
If your using unicorn, or forking in general, you need to restart [Celluloid](https://github.com/celluloid/celluloid) after forking. Celluloid is how Announcer handles publishing
events asynchronously.

For unicorn, in your config (e.g., `unicorn.rb`) you need to specify the following in your `after_fork` callback:

```ruby
if defined?(Celluloid)
  Celluloid.shutdown
  Celluloid.boot
end
```

This will ensure that events will continue to be published asynchronously in your web processes.

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

#### Custom Blocks
You can also specify custom blocks as publishers:

```ruby
Announcer.config do
  publish_to do |event|
    puts "An event has occurred: #{event.name} #{event.params}"
  end
end
```

Be careful not to do anything too time consuming, as all publishers are executed
synchronously when you publish an event.

### Plugins
Announcer uses the [payout/plugins](https://github.com/payout/plugins) gem and currently supports the following hooks:
 * publish
 * resque_publish
 * subscription

You can enable plugins via the config block:

```ruby
Announcer.config {
  plugin :plugin_name, additional_args: 'go here'
}
```

Or outside a config block via the `Instance#plugin` method:

```ruby
Announcer.plugin(:plugin_name, additional_args: 'go here')
```

There is currently one built-in plugin: `:logging`.
#### Logging

```ruby
Announcer.config {
  # Default options shown here.
  plugin :logging, logger: Logger.new(STDOUT), level: :info, log_exceptions: false
}
```

When this plugin is enabled, debug messages will be logged before and after each of the above listed hooks. If log_exceptions is enabled, then the plugin will catch, log and reraise any exceptions.

#### Custom Plugins
You can also add your own custom plugins:

```ruby
Announcer.config {
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

See [payout/plugins](https://github.com/payout/plugins) for more details on defining plugins.
