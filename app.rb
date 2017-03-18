$LOAD_PATH.unshift(File.dirname(__FILE__))
$0 = "qiwibot app"

require 'eventmachine'
require 'rack'
require 'thin'
require 'logger'
require 'pry'

module Qiwibot
  autoload :Server, 'lib/qiwibot/server'
  autoload :Agent, 'lib/qiwibot/agent'
  autoload :Api, 'lib/qiwibot/api'
  autoload :SmsMessage, 'lib/qiwibot/sms_message'
end

# start the application
server = Qiwibot::Server.new({
                                 login: ENV['LOGIN'],
                                 password: ENV['PASSWORD'],
                                 host: ENV['HOST'],
                                 port: ENV['PORT'],
                                 server: ENV['SERVER'],
                                 sms_port: ENV['SMS_PORT'],
                                 sms_host: ENV['SMS_HOST']
                             })
server.run