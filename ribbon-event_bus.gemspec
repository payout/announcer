$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "ribbon/event_bus/version"

Gem::Specification.new do |s|
  s.name        = 'ribbon-event_bus'
  s.version     = Ribbon::EventBus::VERSION
  s.homepage    = "http://github.com/ribbon/event_bus"
  s.license     = 'BSD'
  s.summary     = "An asynchronous event bus for Ruby."
  s.description = s.summary
  s.authors     = ["Robert Honer"]
  s.email       = ['robert@ribbonpayments.com']
  s.files       = Dir['lib/**/*.rb'] + Dir['config/**/*']

  s.add_dependency 'ribbon-plugins', '~> 0.2', '>= 0.2.4'

  s.add_development_dependency 'rails', '~> 4.0.13'
  s.add_development_dependency "sqlite3"
  s.add_development_dependency 'redis'
  s.add_development_dependency 'redis-namespace'
  s.add_development_dependency 'resque', '~> 1.25.2'
  s.add_development_dependency 'mock_redis'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-rails'
end