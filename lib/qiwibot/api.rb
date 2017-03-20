module Qiwibot
  class Api
    include JsonHelpers

    COMMANDS = %w(balance transaction_history send_money make_order)

    attr_accessor :agent

    def initialize(agent)
      @agent = agent
    end

    def call(env)
      request = Rack::Request.new env
      command = request.path_info.match(/\/(?<name>\w+)/)[:name]

      if command && COMMANDS.include?(command)
        begin
          params = request.params.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }
          result = agent.send command, params
          json_response result
        rescue => e
          json_response({message: "[#{e.class}] #{e.message}"}, 500)
        end
      else
        json_response({message: 'unknown command'}, 404)
      end
    end

  end
end