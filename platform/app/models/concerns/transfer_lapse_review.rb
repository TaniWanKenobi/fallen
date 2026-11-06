# frozen_string_literal: true

# The Lapse and Lookout recordings behind a transferred project, checked the way Fallout's time audit checks them
# (/admin/transfers/:id/lapse). The reviewer types the person's Hackatime user id and the Hackatime projects the other
# program tracked; nothing fills them in from the other program, so a transfer can't point the review at someone
# else's account. FetchTransferLapseJob then reads those projects' Lapse and Lookout heartbeats, whose entity names the
# recording, and looks each one up.
#
# The reviewer marks stretches of each video as removed (none of it counts) or deflated (a share of it counts), in video
# seconds, and the time left is `lapse_seconds`, a guide for the hours they approve. A video second stands for
# `seconds / video_seconds` real seconds, measured from the video when the page loads it, or 60 until then.
module TransferLapseReview
  extend ActiveSupport::Concern

  LAPSE_ENTITY = /\(([A-Za-z0-9_-]{6,})\)\s*\z/
  LOOKOUT_ENTITY = /\A\h{32,}\z/
  SEGMENT_TYPES = %w[removed deflated].freeze
  REAL_SECONDS_PER_VIDEO_SECOND = 60
  MAX_PROJECTS = 10
  MAX_RECORDINGS = 200
  MAX_SEGMENTS = 100

  included do
    validates :hackatime_user_id, format: { with: /\A\d+\z/, message: "is the number on their Hackatime admin page" }, allow_blank: true
  end

  class_methods do
    # What one recording's annotation leaves of its time, in seconds.
    def lapse_approved_seconds(recording, note)
      seconds = recording["seconds"].to_i
      video = note&.dig("video_seconds").to_f
      scale = video.positive? ? seconds / video : REAL_SECONDS_PER_VIDEO_SECOND
      cut = Array(note&.dig("segments")).sum do |segment|
        length = (segment["end"].to_f - segment["start"].to_f) * scale
        segment["type"] == "removed" ? length : length * segment["percent"].to_f / 100
      end
      (seconds - cut).round.clamp(0, seconds)
    end
  end

  def lapse_requested? = hackatime_user_id.present? && hackatime_projects.any?
  def lapse_fetching? = lapse_requested? && lapse_fetched_at.nil?

  # Points the review at a Hackatime account and its projects, and forgets what was found for the last ones.
  def request_lapse(user_id:, projects:)
    names = projects.is_a?(String) ? projects.split(/[,\n]/) : Array(projects)
    assign_attributes(hackatime_user_id: user_id.to_s.strip.presence, hackatime_projects: names.map { it.to_s.strip }.compact_blank.uniq.first(MAX_PROJECTS),
                      lapse_recordings: nil, lapse_seconds: nil, lapse_fetched_at: nil, lapse_error: nil)
    save
  end

  def fetch_lapse!
    return unless lapse_requested?

    beats = hackatime_projects.flat_map do |project|
      Hackatime.heartbeats(hackatime_user_id, project: project, editor: "lapse") + Hackatime.heartbeats(hackatime_user_id, project: project, language: "Lookout")
    end
    recordings = beats.group_by { recording_ref(it) }.except(nil).first(MAX_RECORDINGS).map { |(kind, id), group| recording(kind, id, group) }
    recordings.sort_by! { Time.zone.parse(it["started_at"]) }
    update!(lapse_recordings: recordings, lapse_seconds: lapse_total(recordings, lapse_annotations), lapse_fetched_at: Time.current, lapse_error: nil)
  rescue Hackatime::Error, Lapse::Error, Lookout::Error, Faraday::Error, JSON::ParserError => e
    update!(lapse_error: e.message, lapse_fetched_at: Time.current)
  end

  # Keeps the reviewer's notes on the recordings found, as `{ key => { reviewed, description, video_seconds, segments } }`
  # with segments `{ type, start, end, reason, percent }` in video seconds.
  def annotate_lapse(annotations)
    recordings = Array(lapse_recordings).index_by { it["key"] }
    clean = annotations.to_h.slice(*recordings.keys).to_h { |key, note| [ key, clean_note(note.to_h) ] }
    update(lapse_annotations: clean, lapse_seconds: lapse_total(recordings.values, clean))
  end

  private

  def recording_ref(beat)
    entity = beat["entity"].to_s
    if beat["editor"] == "lapse" && (id = entity[LAPSE_ENTITY, 1])
      [ "lapse", id ]
    elsif beat["language"] == "Lookout" && entity.match?(LOOKOUT_ENTITY)
      [ "lookout", entity ]
    end
  end

  def recording(kind, id, beats)
    times = beats.map { it["time"].to_f }
    base = { "kind" => kind, "project" => beats.first["project"], "heartbeats" => beats.size,
             "first_heartbeat_at" => Time.zone.at(times.min).iso8601, "last_heartbeat_at" => Time.zone.at(times.max).iso8601 }
    found = kind == "lapse" ? lapse_recording(id, beats.first["entity"].to_s) : lookout_recording(id)
    # One the other side no longer shows is placed by its first heartbeat instead.
    base.merge(found).tap { it["started_at"] ||= it["first_heartbeat_at"] }
  end

  def lapse_recording(id, entity)
    timelapse = Lapse.public_timelapse(id)
    return { "key" => "lapse:#{id}", "name" => entity.sub(LAPSE_ENTITY, "").strip, "missing" => true, "seconds" => 0, "url" => Lapse.timelapse_url(id) } unless timelapse

    {
      "key" => "lapse:#{id}", "name" => timelapse["name"], "missing" => false, "seconds" => timelapse["duration"].to_i,
      "started_at" => timelapse["createdAt"] && Time.zone.at(timelapse["createdAt"] / 1000.0).iso8601,
      "playback_url" => timelapse["playbackUrl"], "thumbnail_url" => timelapse["thumbnailUrl"], "url" => Lapse.timelapse_url(id),
      "visibility" => timelapse["visibility"], "owner_hackatime_id" => timelapse.dig("owner", "hackatimeId")&.to_s,
      "owner_slack_id" => timelapse.dig("owner", "slackId")
    }
  end

  # The token reads (and while recording, writes) the session, so only a digest of it is kept.
  def lookout_recording(token)
    key = "lookout:#{Digest::SHA256.hexdigest(token).first(16)}"
    session = Lookout.session(token)
    return { "key" => key, "name" => "Lookout session", "missing" => true, "seconds" => 0 } unless session

    {
      "key" => key, "name" => session["name"], "missing" => false, "seconds" => session["trackedSeconds"].to_i,
      "started_at" => session["startedAt"] || session["createdAt"], "playback_url" => session["videoUrl"],
      "thumbnail_url" => session["thumbnailUrl"], "status" => session["status"], "program" => session["program"]
    }
  end

  def lapse_total(recordings, annotations)
    recordings.sum { self.class.lapse_approved_seconds(it, annotations[it["key"]]) }
  end

  def clean_note(note)
    video = note["video_seconds"].to_f
    segments = Array(note["segments"]).first(MAX_SEGMENTS).filter_map { clean_segment(it.to_h) }.sort_by { it["start"] }
    segments = segments.each_with_object([]) { |segment, kept| kept << segment unless kept.last && segment["start"] < kept.last["end"] }
    {
      "reviewed" => ActiveModel::Type::Boolean.new.cast(note["reviewed"]) || false,
      "description" => note["description"].to_s.strip.truncate(2_000).presence,
      "video_seconds" => video.positive? ? video.round(2) : nil,
      "segments" => segments
    }.compact
  end

  def clean_segment(segment)
    start = segment["start"].to_f
    finish = segment["end"].to_f
    return unless segment["type"].in?(SEGMENT_TYPES) && start >= 0 && finish > start

    clean = { "type" => segment["type"], "start" => start.round(2), "end" => finish.round(2), "reason" => segment["reason"].to_s.strip.truncate(200) }
    segment["type"] == "deflated" ? clean.merge("percent" => segment["percent"].to_f.clamp(0, 100).round(2)) : clean
  end
end
