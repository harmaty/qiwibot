require 'eventmachine'
require 'rack'
require 'thin'
require 'logger'
require 'pry'
require 'jwt'
require 'json'

module Qiwibot
  autoload :Server,      'lib/qiwibot/server'
  autoload :Agent,       'lib/qiwibot/agent'
  autoload :Api,         'lib/qiwibot/api'
  autoload :JwtAuth,     'lib/qiwibot/jwt_auth'
  autoload :SmsMessage,  'lib/qiwibot/sms_message'
  autoload :JsonHelpers, 'lib/qiwibot/json_helpers'
end