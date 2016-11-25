load 'lib/server.rb'
load 'lib/agent.rb'

server = Server.new ENV['LOGIN'], ENV['PASSWORD'], ENV['host'], ENV['PORT']
server.run