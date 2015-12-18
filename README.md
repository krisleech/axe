# Axe (Alpha)

A small stream processing framework for routing Kafka topics to parallelized Ruby objects.

* pluggable deseriazation of message payload (inc. JSON and AVRO)
* plugable payload compression / encryption (inc. GZIP and Snappy)
* pluggable consumer offset management (inc. memory and disk)
* process per handler for memory isolation
* preforking for reduced memory consumption

## Usage

### Handlers

A handler is an object which responds to `#call(message)` or a lambda.

```ruby
class MyHandler
  def call(message)
    puts message
  end
end
```

Each handler can be mapped to one Kafka topic. Messages are received in time
order.

If an exception occurs the handler will be stopped and the error reported so it can be fixed before further
messages are consumed.

Each Handler is run in its own preforked process.

### Configure an Application

```ruby
app = Axe::App.new(logger: Logger.new(...),
                   exception_handler: lambda { |exception, consumer| ... })
```

* `logger` - a [Logger](http://ruby-doc.org/stdlib-2.2.3/libdoc/logger/rdoc/Logger.html) instance
* `exception_handler` - any callable object. This is typically used to generate a notification. There is no need to re-raise the error as the handler will be stopped so the exception can be fixed before proceeding.

Also see: [examples/app.rb](https://github.com/krisleech/axe/tree/master/examples).

### Registering Handlers

```ruby
app.register(id:      "my_handler",
             topic:   "test",
             handler: MyHandler.new,
             parser:  Axe::App::JsonParser.new,
             logger:  Logger.new(...),
             retries: 3,
             delay:   5)
```

* `id` - an identifier, it is what the offsets are keyed on. Therefore
  changing it will mean the handler will get events from offset 0. Likewise
  reusing a previously used offset will mean the handler will start from the
  offset stored for that id.
* `topic` - the Kafka topic.
* `handler` - an object which responds to `#call(message)`.
* `parser` - an object which responds to `#call(message)`, it will parse the
  message before passing it to the handler.
    Included handlers are:
    * `JSON`
    * `Avro`
    * `Gzip`
    * `Snappy`
    * `Default` (no parsing)
* `logger` - the logger for this handler, if not specified the default
  application logger is used. (optional)
* `delay` - the number of seconds to pause between batches of messages (optional)
* `retries` - the number of times the handler will be retried when an error
  occurs. (optional)

If you need to use multiple parsers, e.g. for decompression, you can pass
an array of parsers:

```ruby
app.register(...,
             parser:  [Axe::App::GzipParser.new, Axe::App::JsonParser.new])
```

The same technique can be used for decryption too.

### Starting the Application

```ruby
app.start
```

This will block until stopped. If all handlers are stopped, e.g. due to exceptions, then the application will stop.

Axe does not handler demonization, pid files, restart etc. You can either use Ruby to do this or use something like initd.

If a connection to Kafka can not be established Axe will keep retrying until it becomes available.

Often topics are auto-created when the first message is published. If a topic does not exist Axe will print a warning to the log file and continue to keep trying until the topic is created.

The application process name will be `axe [master]`. Each child process with be named by its id, e.g. `axe [my_handler]`.

### Stopping the Application

To stop the app gracefully send a TERM signal, e.g. Ctrl-C if the process is not demonized, to the master process.

This will ensure that any messages currently being processed are allowed to finish.

Failure to gracefully shutdown could result in a handlers getting their last
message for a second time.

There is no need to send signals to the child processes.

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

### Writing parsers

A parser is any object which responds to `#call(messages)` where `message` is a
String. It must return the parsed message, this can be any Ruby object,
typically it will be a Hash.

Take a look at the [build in parsers](https://github.com/krisleech/axe/tree/master/lib/axe/app/parsers) for examples.

### Writing offsets stores

An offset store is an object which responds to `#[]` and `#[]=`. An in-memory
offset store could be implemented using a Hash.

```
app = Axe::App.new(offset_store: Hash.new)
```

Take a look at the [build in stores](https://github.com/krisleech/axe/tree/master/lib/axe/app/offset_stores)
for further examples.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/krisleech/axe](https://github.com/krisleech/axe). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## Releasing

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).