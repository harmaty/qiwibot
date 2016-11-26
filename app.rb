require 'logger'
load 'lib/server.rb'
load 'lib/agent.rb'

server = Server.new ENV['LOGIN'], ENV['PASSWORD'], ENV['host'] || 'localhost', ENV['PORT'] || 8081
server.run