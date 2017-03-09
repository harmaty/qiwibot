require 'logger'
load 'lib/server.rb'
load 'lib/agent.rb'
load 'lib/sms_messages.rb'

server = Server.new ENV['LOGIN'], ENV['PASSWORD'], ENV['HOST'] || 'localhost', ENV['PORT'] || 8081
server.run