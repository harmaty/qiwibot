require 'net/https'
require "json"
require 'uri'
require 'rack'

class SmsMessages

  def initialize(server, token)
    @server, @token = server, token
  end

  def get(options)
    url = URI(server)
    url.query = Rack::Utils.build_query options
    Net::HTTP::Get

  end
end