require 'socket'
require 'json'

class Server

  COMMANDS = %w(balance transaction_history send_money_by_chunks make_order)

  def initialize(login, password, host = 'localhost', port = 8081)
    @login, @password, @host, @port = login, password, host, port
  end

  def agent
    @agent ||= Agent.new @login, @password
  end

  def run
    agent.start
    server = TCPServer.open('localhost', 8081)
    loop {
      puts 'in loop'
      client = server.accept # Wait for a client to connect
      data = client.gets.strip
      puts "client entered: #{data}"
      input = JSON.parse("#{data}")

      # unless agent.browser.exists?
      #   agent.start
      # end
      response = if COMMANDS.include? input['command']
                   begin
                     agent.send input['command'], *input['arguments']
                   rescue Exception => e
                     {error: e.message}
                   end
                 else
                   'unknown command'
                 end

      puts response
      client.puts response.to_json
      client.close # Disconnect from the client
    }
  end

end