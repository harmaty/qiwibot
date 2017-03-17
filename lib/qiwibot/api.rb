require 'json'
require 'pry'

module Qiwibot
  class Api
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
          json_response({message: e.message}, 400)
        end
      else
        json_response({message: 'unknown command'}, 404)
      end
    end

    private

    def json_response(result, status = 200, headers = {})
      [status, headers, result.to_json]
    end
  end
end