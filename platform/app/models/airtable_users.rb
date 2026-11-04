# frozen_string_literal: true

# Copies every user to the Users table in Airtable through the Sync API (Airtable.sync), keyed on ID, their public id.
# The table is set up once in Airtable as a Sync API table (AIRTABLE_USERS_TABLE, AIRTABLE_USERS_SYNC_ID) with ID as
# its unique field. A user deleted here, including by a privacy request, drops out of Airtable on the next upload.
# Trial accounts (User#trial?) go too, with no HCA ID until they sign in with it. Tokens never leave the app.
module AirtableUsers
  module_function

  BATCH = 500
  TOKENS = %w[hca_token slack_user_token lapse_token].freeze

  # Read in batches so no one statement carries the whole table: a worker short of CPU just after a deploy once read
  # the single 3.5 MB result slowly enough to hit statement_timeout.
  def sync(batch_size: BATCH)
    rows = users.find_in_batches(batch_size:).flat_map { rows(it) }
    Airtable.sync(ENV.fetch("AIRTABLE_USERS_TABLE", "Users"), ENV.fetch("AIRTABLE_USERS_SYNC_ID"), rows) if rows.any?
    rows.size
  end

  # Users without their encrypted tokens, which are most of a row's bytes and never uploaded; Slack Connected only needs
  # to know whether one is set (disconnecting clears it to nil, as ProgramStats assumes).
  def users = User.select(*(User.column_names - TOKENS), "slack_user_token IS NOT NULL AS slack_token_set")

  # Two grouped queries per batch, one per table, with every aggregate in each: one statement apiece per aggregate
  # repeated the same journals scan four times and Sentry flagged it as an N+1.
  def rows(users)
    ids = users.map(&:id)
    journals = Journal.kept.where(user_id: ids).group(:user_id)
      .pluck(:user_id, Arel.sql("COUNT(*)"), Arel.sql("SUM(duration_minutes)"), Arel.sql("MIN(created_at)"), Arel.sql("MAX(created_at)"))
      .to_h { |id, *values| [ id, values ] }
    projects = Project.kept.where(user_id: ids).group(:user_id)
      .pluck(:user_id, Arel.sql("COUNT(*)"), Arel.sql("COUNT(*) FILTER (WHERE approved_at IS NOT NULL)"))
      .to_h { |id, *values| [ id, values ] }
    users.map { |user| row(user, journals.fetch(user.id, []), projects.fetch(user.id, [])) }
  end

  def row(user, journals, projects)
    journal_count, minutes, first_journal, last_journal = journals
    project_count, approved = projects
    approved = approved.to_i
    {
      "ID" => user.public_id,
      "Name" => user.display_name,
      "Email" => user.email,
      "HCA ID" => user.hca_id,
      "Trial" => user.trial?,
      "Slack ID" => user.slack_id,
      "Avatar" => user.avatar_url.start_with?("http") ? user.avatar_url : nil,
      "Verification Status" => user.verification_status,
      "Adult" => user.is_adult,
      "Banned" => user.is_banned,
      "Roles" => user.roles,
      "Timezone" => user.timezone,
      "Pet" => user.pet,
      "Slack Connected" => user.slack_token_set,
      "XP" => user.xp,
      "XP Multiplier" => user.xp_multiplier.to_f,
      "Streak Freezes" => user.streak_freezes,
      "Stage" => user.hatched? ? Evolution.stage(user.xp) { approved.positive? } : 0,
      "Projects" => project_count.to_i,
      "Approved Projects" => approved,
      "Journals" => journal_count.to_i,
      "Hours" => (minutes.to_i / 60.0).round(2),
      "First Journal At" => first_journal&.iso8601,
      "Last Journal At" => last_journal&.iso8601,
      "Last Seen At" => user.last_seen_at&.iso8601,
      "Signed Up At" => user.created_at.iso8601,
      "UTM Source" => user.signup_source["utm_source"],
      "UTM Medium" => user.signup_source["utm_medium"],
      "UTM Campaign" => user.signup_source["utm_campaign"],
      "UTM Term" => user.signup_source["utm_term"],
      "UTM Content" => user.signup_source["utm_content"],
      "Ref" => user.signup_source["ref"],
      "Referrer" => user.signup_source["referrer"],
      "Landing Page" => user.signup_source["landing_path"],
      "Deleted At" => user.discarded_at&.iso8601
    }
  end
end
