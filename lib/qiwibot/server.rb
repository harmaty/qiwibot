module Qiwibot
  class Server

    attr_accessor :login, :password, :host, :port, :server, :sms_host, :sms_port

    def initialize(options)
      @login, @password = options[:login], options[:password]
      @server = options[:server] || 'thin'
      @host = options[:host] || '0.0.0.0'
      @port = options[:port] || '8081'
      @sms_host = options[:sms_host] || '0.0.0.0'
      @sms_port = options[:sms_port] || '8082'
    end

    def agent
      @agent ||= Agent.new login, password, sms_host, sms_port
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
        EM::PeriodicTimer.new(60) do
          agent.start unless agent.alive?
          agent.login unless agent.logged_in?
        end
      end
    end
  end
end