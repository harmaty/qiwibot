require 'socket'
require 'eventmachine'

module Qiwibot
  class SmsMessage

    attr_accessor :pattern, :host, :port

    def initialize(pattern: /Kod\:\s(\d+)/, host: '0.0.0.0', port: 8082)
      @pattern, @host, @port = pattern, host, port
    end

    def receive
      server = TCPServer.open(host, port)

      data = ''
      loop do
        puts "Waiting for sms on #{host}:#{port}"
        client = server.accept # Wait for a client to connect
        data = client.gets.strip
        puts "Received: '#{data}'"
        client.puts 'ok'
        client.close # Disconnect from the client
        break if data.match(pattern)
      end

      data.scan(pattern).flatten.first
    ensure
      server.close
    end
  end
end

