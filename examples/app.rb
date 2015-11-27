require 'bundler'

Bundler.setup

require 'axe'
require 'pry'


# event handlers must implement #call(payload)
class TestHandler
  def call(payload)
    puts "[TEST] #{payload}"
    sleep(5) # this will not hold up other handlers
  end
end

class SystemHandler
  def call(payload)
    puts "[SYS] #{payload}"
  end
end

class OtherHandler
  def call(payload)
    puts "[OTH] #{payload}"
    raise 'some error'# if rand(2) == 1
  end
end

class MultiHandler
  def call(payload)
    puts "[MULTI] #{payload}"
  end
end

AppRoot = Pathname(__dir__)

puts AppRoot.to_s

# create directories
%w(log db).each do |dir|
  dir = AppRoot.join(dir).to_s
  next if Dir.exists?(dir)
  puts "Creating #{dir}"
  Dir.mkdir(dir)
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

# Signal.trap('USR1') do
#   puts "#{app.status}"
# end

app.register(id: 'kris',
            topic: 'test',
            handler: TestHandler.new)

app.register(id: 'sys',
            topic: 'test2',
            handler: SystemHandler.new)

app.register(id: 'other',
            topic: 'test2',
            handler: OtherHandler.new)

app.register(id: 'multi',
            topic: 'test',
            handler: MultiHandler.new)

app.register(id: 'multi',
            topic: 'test2',
            handler: MultiHandler.new)

app.start

exit(0)
