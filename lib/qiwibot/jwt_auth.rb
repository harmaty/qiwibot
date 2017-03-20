module Qiwibot
  class JwtAuth
    include JsonHelpers

    def initialize app
      @app = app
    end

    def call env
      begin
        bearer = env.fetch('HTTP_AUTHORIZATION', '').slice(7..-1)
        payload, header = JWT.decode bearer, ENV['JWT_SECRET'], true, {algorithm: 'HS256'}
        env[:operation] = payload['operation']

        @app.call env
      rescue JWT::ExpiredSignature
        json_response({message: 'The token has expired.'}, 403)
      rescue JWT::DecodeError
        json_response({message: 'A token must be passed.'}, 401)
      end
    end

  end
end
