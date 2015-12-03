require 'bundler'

Bundler.setup

require 'axe'
require 'pry'

class Handler
  def initialize(label)
    @label = label
  end

  private

  def log(msg)
    puts "[#{@label}] #{msg}"
  end
end

class BasicHandler < Handler
  def call(payload)
    log "#{payload.class.name} #{payload}"
  end
end

class SlowHandler < BasicHandler
  def call(payload)
    super(payload)
    sleep(5) # this will not hold up other handlers
  end
end

class BrokenHandler < BasicHandler
  def call(payload)
    super(payload)
    raise 'some error'
  end
end

AppRoot = Pathname(__dir__)

# create directories
%w(log db).each do |dir|
  dir = AppRoot.join(dir).to_s
  next if Dir.exists?(dir)
  puts "Creating #{dir}"
  Dir.mkdir(dir)
end

demonize = ARGV.include?('-d')

if demonize
  puts "pid: #{Process.pid}"
  Process.daemon
end

require 'logger'
logger = Logger.new(AppRoot.join('log', 'axe.log').to_s)

app = Axe::App.new(logger: logger,
                   offset_store: Axe::App::FileOffsetStore.new(path: AppRoot.join('db')))

# Graceful shutdown
# Thread needed because of https://bugs.ruby-lang.org/issues/7917
%w(INT TERM QUIT).each do |signal|
  Signal.trap(signal) { Thread.new { app.stop } }
end

app.register(id: 'basic_test',
            topic: 'basic_test',
            handler: BasicHandler.new('BASIC'))

app.register(id: 'broken',
            topic: 'basic_test',
            handler: BrokenHandler.new('BROKEN'))

app.register(id: 'no_topic',
            topic: 'does_not_exist',
            handler: BasicHandler.new('BASIC'))

app.register(id: 'json_test',
            topic: 'json_test_1',
            handler: BasicHandler.new('JSON'),
            parser: Axe::App::JSONParser.new)

app.register(id: 'avro_test',
            topic: 'avro_test_1',
            handler: BasicHandler.new('AVRO'),
            parser: Axe::App::AvroParser.new)


app.start

exit(0)
