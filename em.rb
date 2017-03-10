$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'eventmachine'
require 'rack'
require 'thin'

module Qiwibot
  autoload :Server, 'lib/qiwibot/server'
  autoload :Agent, 'lib/qiwibot/agent'
  autoload :Api, 'lib/qiwibot/api'
end

# start the application
server = Qiwibot::Server.new({
                                 login: ENV['LOGIN'],
                                 password: ENV['PASSWORD'],
                                 host: ENV['HOST'],
                                 port: ENV['PORT'],
                                 server: ENV['SERVER']
                             })
server.run