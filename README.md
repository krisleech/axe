# Axe (Alpha)

A small framework for routing a stream of events to parallelized consumers.

* deseriazation of event payload
* consumer offset management
* consumer local state
* consumer publishing new streams
* stats for each stream and consumer

## Setup

Currently Axe has no application template.

See `app.rb` for an example app.

Run it as such:

```
rerun ruby app.rb
```

(rerun will reload the code when a Ruby file changes)

A minimal app looks like this:

```ruby
require 'bundler'
Bundler.setup

require 'axe'

class MyConsumer
  def call(message)
    puts message
  end
end

app = Axe::App.new(logger: Logger.new('logs/axe.log'))

app.register(id:      "my_test_consumer",
             topic:   "test",
             handler: MyConsumer.new)

app.start
```

Each Handler is mapped to a topic.

The application will maintain the offset in the topic between restarts.

Handlers will receive messages in the correct. This means if an exception
occurs the handlers will be stopped.

Handlers are all run in parrell in their own processes.

## Usage

### Configuration

```ruby
app.configure do |config|
  config.logger = Logger.new(...)
  config.exception_handler = lambda { |exception, consumer| ... }
  config.exception_policy = :stop # TODO
  config.transaction_wrapper = lambda { Sequel.transaction { yield } } # TODO
end
```

### Registering consumers

```ruby
app.register(id: "recruitment/study_projection",
             topic: "recruitment",
             handler: Recruitment::StudyProjection.new,
             parser: Axe::App::JsonParser.new,
             retries: 3,
             delay: 5)
```

* `id` is an identifier, it is what the offsets are keyed on. Therefore
  changing it will mean the handler will get events from offset 0. Likewise
  reusing a previously used offset will mean the handler will start from the
  offset stored for that offset.
* `topic` is the Kafka topic
* `handler` an object which responds to `#call(message)`.
* `parser` is an object which responds to `#call(message)`, it will parse the
  message before passing it to the handler.
* `delay` the number of seconds to pause between batches of messages
* `retries` the number of time the handler will be retried when an error
  occurs.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/axe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

