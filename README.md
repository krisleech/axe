# Axe (Alpha)

A small framework for routing a stream of events to parallelized consumers.

* pluggable deseriazation of event payload (inc. JSON and AVRO)
* plugable payload compression / encryption
* pluggable consumer offset management
* consumer local state
* consumer stream publishing
* stats for each stream and consumer
* process per handler for memory isolation
* preforking for reduced memory consumption

## Setup

Currently Axe has no application template.

See `examples/app.rb` for an example app.

Run it as such:

```
ruby app.rb
```

A minimal app looks like this:

```ruby
require 'bundler'
Bundler.setup

require 'axe'

class MyHandler
  def call(message)
    puts message
  end
end

app = Axe::App.new(logger: Logger.new('logs/axe.log'))

app.register(id:      "my_test_consumer",
             topic:   "test",
             handler: MyHandler.new)

app.start
```

Each Handler is mapped to a topic.

The application will maintain the offset in the topic between restarts.

Handlers will receive messages in the correct order. This means if an exception
occurs the handlers will be stopped so the error can be fixed before further
events are consumed.

Handlers are all run in parrell in their own processes.

## Starting and stopping

When you start the app the process name will be changed to `axe [master]`. To
stop the app gracefully you can either Ctrl+C if the process is not demonized
or send a TERM signal. This will ensure that any message currently being
processed are allowed to finish.

Failure to gracefully shutdown could result in a handlers getting their last
message again.

## Usage

### Configuration

```ruby
app.configure do |config|
  config.logger              = Logger.new(...)
  config.exception_handler   = lambda { |exception, consumer| ... }
  config.exception_policy    = :stop # TODO
  config.transaction_wrapper = lambda { Sequel.transaction { yield } } # TODO
  config.default_parser      = Axe::App::JSONParser.new
end
```

### Registering consumers

```ruby
app.register(id:      "recruitment/study_projection",
             topic:   "recruitment",
             handler: Recruitment::StudyProjection.new,
             parser:  Axe::App::JsonParser.new,
             logger:  Logger.new(...),
             retries: 3,
             delay:   5)
```

* `id` is an identifier, it is what the offsets are keyed on. Therefore
  changing it will mean the handler will get events from offset 0. Likewise
  reusing a previously used offset will mean the handler will start from the
  offset stored for that offset.
* `topic` is the Kafka topic
* `handler` an object which responds to `#call(message)`.
* `parser` is an object which responds to `#call(message)`, it will parse the
  message before passing it to the handler.
    Included handlers are:
    * `JSON`
    * `Avro`
    * `Gzip`
    * `Snappy`
    * `Default` (no parsing)
* `logger` is the logger for this handler, if not specified the default
  application logger is used.
* `delay` the number of seconds to pause between batches of messages
* `retries` the number of time the handler will be retried when an error
  occurs.

If you need to use multiple parsers, e.g. for decompression, you can pass
an array of parsers:

```ruby
app.register(...,
             parser:  [Axe::App::GzipParser.new, Axe::App::JsonParser.new])
```

The same technique can be used for decryption too.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Specs

```
bundle exec rspec
```

Run on code change:

```
ls **/*.rb | entr -c bundle exec rspec
```

You can run the sample app and have it restart on code change with:

```
rerun ruby app.rb
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/krisleech/axe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## Releasing

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

