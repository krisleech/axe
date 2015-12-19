# Example App

Firstly start Zookeeper and Kafka.

```
$ zkServer start-foreground
$ kafka-server-start.sh /usr/local/etc/kafka/server.properties
```

Then start the Axe Application:

```
$ ruby app.rb
```

You can specify the Kafka port via ENV:

```
$ env KAFKA_HOST=kafka.example.com ruby app.rb
```

Populate the topics used in the example app with:

```
$ ruby avro_producer.rb
$ ruby json_producer.rb
$ ruby string_producer.rb
```
