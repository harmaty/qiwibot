module Qiwibot
  module JsonHelpers
    def json_response(result, status = 200, headers = {'Content-Type' => 'application/json'})
      [status, headers, result.to_json]
    end
  end
end