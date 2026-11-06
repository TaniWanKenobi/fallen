# frozen_string_literal: true

# Hackatime (https://hackatime.hackclub.com), Hack Club's coding-time tracker. Fallen only reads heartbeats through its
# admin API, to find the Lapse and Lookout recordings a transferred project logged (ProjectTransfer::LapseReview). Set
# HACKATIME_ADMIN_API_KEY to an admin API key made at hackatime.hackclub.com/admin/admin_api_keys.
module Hackatime
  class Error < StandardError; end

  HOST = "https://hackatime.hackclub.com"
  PAGE_SIZE = 5_000
  MAX_PAGES = 10

  module_function

  def configured? = ENV["HACKATIME_ADMIN_API_KEY"].present?

  # Every heartbeat of one Hackatime user matching the filters (project, editor, language...), oldest first.
  def heartbeats(user_id, **filters)
    raise Error, "HACKATIME_ADMIN_API_KEY is not set" unless configured?

    MAX_PAGES.times.each_with_object([]) do |page, rows|
      data = get("/api/admin/v1/user/heartbeats", { id: user_id, limit: PAGE_SIZE, offset: page * PAGE_SIZE, **filters })
      rows.concat(Array(data["heartbeats"]))
      break rows unless data["has_more"]
    end
  end

  def get(path, params)
    response = connection.get(path, params)
    raise Error, "Hackatime has no user #{params[:id]}" if response.status == 404
    raise Error, "Hackatime refused the admin API key (#{response.status})" if response.status.in?([ 401, 403 ])
    raise Error, "Hackatime #{path} failed (#{response.status})" unless response.success?

    JSON.parse(response.body)
  end

  def connection
    Faraday.new(url: HOST, headers: { "Authorization" => "Bearer #{ENV.fetch('HACKATIME_ADMIN_API_KEY', nil)}", "Accept" => "application/json" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 30
    end
  end
  private_class_method :get
end
