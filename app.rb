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

app = Axe::App.new

# Thread needed because of https://bugs.ruby-lang.org/issues/7917
%w(INT TERM QUIT).each do |signal|
  Signal.trap(signal) { Thread.new { app.stop } }
end

Signal.trap('USR1') do
  puts "#{app.status}"
end

app.register(id: 'kris',
            topic: 'test',
            handler: TestHandler.new)

app.register(id: 'sys',
            topic: 'system',
            handler: SystemHandler.new)

app.run


exit(0)
