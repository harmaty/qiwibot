require 'socket'
require 'json'

class Server

  COMMANDS = %w(balance transaction_history send_money_by_chunks make_order)

  attr_accessor :host, :port

  def initialize(login, password, host, port)
    @login, @password, @host, @port = login, password, host, port
  end

  def agent
    @agent ||= Agent.new @login, @password
  end

  def run
    agent.start
    server = TCPServer.open(host, port)

    loop {
      puts "Serving on #{host}:#{port} ..."
      client = server.accept # Wait for a client to connect
      input = receive_client_request(client)

      response = make_response(input)
      puts response
      client.puts response.to_json
      client.close # Disconnect from the client
    }
  end

  private

  def receive_client_request(client)
    data = client.gets.strip
    puts "client entered: #{data}"
    JSON.parse("#{data}")
  end

  def make_response(input)
    if COMMANDS.include? input['command']
      begin
        agent.send input['command'], *input['arguments']
      rescue Exception => e
        {error: e.message}
      end
    else
      'unknown command'
    end
  end

end