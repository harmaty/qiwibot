$0 = "qiwibot app"
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'lib/qiwibot'

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