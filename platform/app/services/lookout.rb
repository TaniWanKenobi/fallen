# frozen_string_literal: true

# Lookout (https://lookout.hackclub.com), the screen recorder Stardance and Fallout use. A session's Hackatime
# heartbeats carry its token as the entity, and the token reads the session from Lookout's public API.
module Lookout
  class Error < StandardError; end

  HOST = "https://lookout.hackclub.com"

  module_function

  # The session as Lookout returns it, or nil when there's no such session.
  def session(token)
    response = connection.get("/api/sessions/#{ERB::Util.url_encode(token)}")
    return nil if response.status.in?([ 400, 404 ])
    raise Error, "Lookout answered #{response.status}" unless response.success?

    JSON.parse(response.body)
  end

  def connection
    Faraday.new(url: HOST, headers: { "Accept" => "application/json" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 15
    end
  end
end
