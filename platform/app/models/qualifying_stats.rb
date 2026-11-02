# frozen_string_literal: true

# The rest of /admin/qualifying, over people with their status (QualifyingPace.with_status): how many are in each
# status, among builders and on pace to finish; the tabs past the statuses; how far through the hours they are; and
# who is locking in.
module QualifyingStats
  # Recently inactive: on track or just below the line, short of the XP, and no journal in this many days.
  QUIET_DAYS = 3
  # Locking in: journaling at least LOCK_IN_HOURS over the last LOCK_IN_DAYS.
  LOCK_IN_DAYS = 7
  LOCK_IN_HOURS = 12
  # The hours funnel's steps, up to the XP goal's hours.
  HOUR_STEPS = [ 1, 5, 10, 15, 25, 50 ].freeze
  # The list's tabs, in order: the statuses, with recently inactive next to on track.
  TABS = %w[on_track recently_inactive behind off_track qualified not_started].freeze

  # Has written a journal: a builder, so counts can leave out people who signed up and never started.
  BUILDER = "EXISTS (SELECT 1 FROM journals WHERE journals.user_id = users.id AND journals.discarded_at IS NULL)"
  JOURNALED_MINUTES = <<~SQL.squish
    (SELECT COALESCE(SUM(duration_minutes), 0) FROM journals
     WHERE journals.user_id = users.id AND journals.discarded_at IS NULL AND journals.source <> 'transfer')
  SQL
  # Every hour behind someone's XP, transfers' too, so XP over these is what an hour earns them.
  ALL_HOURS = "(SELECT COALESCE(SUM(duration_minutes), 0) FROM journals WHERE journals.user_id = users.id AND journals.discarded_at IS NULL) / 60.0"

  module_function

  def goal_hours = QualifyingPace.goal_xp.fdiv(XpEntry::PER_HOUR).ceil


  def recently_inactive_sql(day, now)
    close = QualifyingPace.by_pet { QualifyingPace.close_xp(it, day - 1) }
    Journal.sanitize_sql_array([ <<~SQL.squish, now - QUIET_DAYS.days ])
      pace_status IN ('on_track', 'behind') AND users.xp >= #{close} AND users.xp < #{QualifyingPace.goal_xp}
      AND NOT EXISTS (SELECT 1 FROM journals WHERE journals.user_id = users.id AND journals.discarded_at IS NULL AND journals.created_at >= ?)
    SQL
  end

  # The people under `tab` (TABS), of `people` with their status.
  def tab(people, tab, day, now = Time.current)
    case tab
    when "recently_inactive" then people.where(recently_inactive_sql(day, now))
    else people.where(pace_status: tab)
    end
  end

  # The hours someone will have spent once they have the XP: every hour so far, then the rest spread evenly over the
  # days from `day` to the deadline with their team's reward paid in full, like the on-track line: Lulu's weekly
  # bonuses still to come, and a Sami streak rising from the multiplier they have now (one an admin set off the steps
  # counts as 1). The same sum for one person (#hours_to_qualify) and in SQL over users, where it is nothing for
  # anyone with no hours, so the average leaves out people whose XP came without any.
  def hours_to_qualify(user, minutes, day)
    multiplier = user.pet == "sami" && Team::Sami.multipliers.include?(user.xp_multiplier) ? user.xp_multiplier : 1
    minutes / 60.0 + xp_left(user.xp, user.pet, day) / reward_rate(user.pet, day, multiplier)
  end

  def hours_to_qualify_sql(day)
    per_hour = QualifyingPace.by_pet do |pet|
      next reward_rate(pet, day) unless pet == "sami"

      "CASE users.xp_multiplier #{Team::Sami.multipliers.map { "WHEN #{it.to_f} THEN #{reward_rate(pet, day, it)}" }.join(" ")} ELSE #{reward_rate(pet, day)} END"
    end
    left = "GREATEST(#{QualifyingPace.goal_xp} - users.xp - #{QualifyingPace.by_pet { QualifyingPace.bonus_xp(it, days_left(day)) }}, 0)"
    "CASE WHEN #{ALL_HOURS} > 0 THEN #{ALL_HOURS} + #{left} / #{per_hour} END"
  end

  # From `day` to the deadline, or just `day` once it has passed.
  def days_left(day) = day..[ QualifyingPace.deadline, day ].max

  # XP an hour earns on average over #days_left, with the team's reward in full and a Sami streak from `multiplier`.
  def reward_rate(pet, day, multiplier = 1) = QualifyingPace.hourly_xp(pet, days_left(day), day, multiplier).fdiv(days_left(day).count)

  # The XP still to make from hours after the team's bonuses still to come.
  def xp_left(xp, pet, day) = [ QualifyingPace.goal_xp - xp - QualifyingPace.bonus_xp(pet, days_left(day)), 0 ].max

  # For each status: everyone, and those who have journaled; then how many are under each tab past the statuses, and
  # the hours to qualify of everyone on track or qualified: the average, and where the middle half of them fall.
  def summary(people, day, now = Time.current)
    per_status = [ "TRUE", BUILDER ].map { count_where(it) }
    on_track = "pace_status IN ('on_track', 'qualified')"
    statuses = people.group(:pace_status).pluck(:pace_status, *per_status.map { Arel.sql(it) })
    totals = [ count_where(recently_inactive_sql(day, now)),
               "AVG(#{hours_to_qualify_sql(day)}) FILTER (WHERE #{on_track})",
               "percentile_cont(ARRAY[0.25, 0.75]) WITHIN GROUP (ORDER BY #{hours_to_qualify_sql(day)}) FILTER (WHERE #{on_track})" ]
    recently_inactive, average, (low, high) = people.pick(*totals.map { Arel.sql(it) })
    {
      statuses: statuses.to_h { |status, all, builders| [ status, { all:, builders: } ] },
      recently_inactive:, hours_to_qualify: average && { average: average.round, low: low.round, high: high.round }
    }
  end

  def count_where(sql) = "COUNT(*) FILTER (WHERE #{sql})"

  # How many of `people` have journaled each of HOUR_STEPS' hours on Fallen, up to the hours the XP goal takes at
  # XpEntry::PER_HOUR, after everyone and the builders.
  def hours_funnel(people)
    steps = HOUR_STEPS.select { it < goal_hours } << goal_hours
    counts = User.from(people.select("#{JOURNALED_MINUTES} AS minutes, #{BUILDER} AS builder"), :people)
      .pick(*[ "COUNT(*)", count_where("builder"), *steps.map { count_where("minutes >= #{it * 60}") } ].map { Arel.sql(it) })
    builders = counts.delete_at(1)
    [ { key: "team", label: "On a team", count: counts.first }, { key: "builders", label: "Wrote a journal", count: builders } ] +
      steps.zip(counts.drop(1)).map { |hours, count| { key: "#{hours}h", label: hours == goal_hours ? "#{hours}h, enough for #{QualifyingPace.goal_xp.to_fs(:delimited)} XP" : "#{hours}h journaled", count: } }
  end

  # Minutes journaled in the last LOCK_IN_DAYS by everyone in `people` who is locking in, by user id, most first.
  def locked_in(people, now = Time.current)
    recent_journals(now).where(user_id: people.select(:id)).group(:user_id)
      .having("SUM(duration_minutes) >= ?", LOCK_IN_HOURS * 60).order(Arel.sql("SUM(duration_minutes) DESC")).sum(:duration_minutes)
  end

  # When each of `user_ids` last journaled on Fallen, the minutes they journaled there in the last LOCK_IN_DAYS, and
  # every minute behind their XP, transfers' too, by user id, as serializer params for a page of rows.
  def journal_activity(user_ids, now = Time.current)
    here = "source <> 'transfer'"
    recent = Journal.sanitize_sql_array([ "COALESCE(SUM(duration_minutes) FILTER (WHERE #{here} AND created_at >= ?), 0)", now - LOCK_IN_DAYS.days ])
    rows = Journal.kept.where(user_id: user_ids).group(:user_id)
      .pluck(:user_id, Arel.sql("MAX(created_at) FILTER (WHERE #{here})"), Arel.sql(recent), Arel.sql("COALESCE(SUM(duration_minutes), 0)"))
    { last_journals: rows.to_h { it.first(2) }, recent_minutes: rows.to_h { [ it[0], it[2] ] }, total_minutes: rows.to_h { [ it[0], it[3] ] } }
  end

  def recent_journals(now) = Journal.kept.written_here.where(created_at: (now - LOCK_IN_DAYS.days)..)
end
