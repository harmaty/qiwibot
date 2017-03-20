module Qiwibot
  class JwtAuth
    include JsonHelpers

    def initialize app
      @app = app
    end

    def call env
      request = Rack::Request.new env
      begin
        bearer = env.fetch('HTTP_AUTHORIZATION', '').slice(7..-1)
        payload, header = JWT.decode bearer, ENV['JWT_SECRET'], true, {algorithm: 'HS256'}
        operation = payload['operation']

        unless operation && request.path_info.include?(operation['command']) && operation['params'] == request.params
          raise 'Invalid token.'
        end

        @app.call env
      rescue JWT::ExpiredSignature
        json_response({message: 'The token has expired.'}, 403)
      rescue JWT::DecodeError
        json_response({message: 'A token must be passed.'}, 401)
      rescue => e
        json_response({message: e.message}, 401)
      end
    end

  end
end
