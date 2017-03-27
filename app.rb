app_name = ARGV[0] ? ARGV[0] : 'app'
$0 = "qiwibot #{app_name}"

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