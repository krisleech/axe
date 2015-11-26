require 'bundler'

Bundler.setup

require 'axe'
require 'pry'


# event handlers must implement #call(payload)
class TestHandler
  def call(payload)
    puts "[TEST] #{Time.now.strftime('%M %S %L %N')} #{payload}"
    sleep(5) # this will not hold up other handlers
  end
end

class SystemHandler
  def call(payload)
    puts "[SYS] #{Time.now.strftime('%M %S %L %N')} #{payload}"
  end
end

require 'logger'
logger = Logger.new('axe.log')

app = Axe::App.new(logger: logger)


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

app.start

exit(0)
