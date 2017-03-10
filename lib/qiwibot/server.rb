module Qiwibot
  class Server

    attr_accessor :login, :password, :host, :port, :server

    def initialize(options)
      @login, @password = options[:login], options[:password]
      @server = options[:server] || 'thin'
      @host = options[:host] || '0.0.0.0'
      @port = options[:port] || '8081'
    end

    def agent
      @agent ||= Agent.new login, password
    end

    def run
      agent.start
      EM.run do
        Rack::Server.start({
                               app: Api.new(agent),
                               server: server,
                               Host: host,
                               Port: port,
                               signals: false
                           })
      end
    end
  end
end