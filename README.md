# Axe (Alpha)

A small framework for routing a stream of events to parallelized consumers.

* deseriazation of event payload
* consumer offset management
* consumer local state
* consumer publishing new streams
* stats for each stream and consumer

To get asynchronicity you need Rubinus or JRuby.

## Setup

Currently Axe has no application template.

See `app.rb` for an example app.

Run it as such:

```
rerun ruby app.rb
```

(rerun will reload the code when a Ruby file changes)

An example app:

```ruby
require 'bundler'
require 'axe'

app = Axe::App.new

app.register(id: "my_consumer",
             topic: "test",
             handler: MyConsumer.new,
             pool: 10,
             offset: "resume")

app.on(:message_consumed) {  }
app.on(:message_received) {  }
app.on(:exception) {  }

app.start
```

Many parts are pluggable, but the default setup is:

Kafka as steam source
Offsets stored on disk

my_app/data/offsets.db
           /local_storage.db

## Usage

### Registering consumers



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/axe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

