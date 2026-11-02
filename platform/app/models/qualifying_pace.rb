# frozen_string_literal: true

# Where someone on each team should be on the way to the final stage's XP (Evolution) by the deadline
# (DailyGoal::DEADLINE), on New York days. On track is steady progress from the race's first day (TeamRace::START):
# the same hours every day with the team's reward paid in full, so Lulu's line climbs evenly with a step for each
# weekly bonus and Sami's curves up as the multiplier rises. Off track is having so little that the rest would take
# more than OFF_TRACK_HOURS a day with the reward in full, a Sami streak going on from the multiplier the person has.
# Team wins, transfers and one-off bonuses are left out of both lines, but all of someone's XP counts towards where
# they are.
module QualifyingPace
  OFF_TRACK_HOURS = 3
  STATUSES = %w[on_track behind off_track qualified not_started].freeze
  # From worst to best, to tell moving up from slipping.
  RANK = %w[not_started off_track behind on_track qualified].freeze
  # The ranges /admin/qualifying looks back over, in days (nil since the race began), for who moved (#history).
  RANGES = { "7d" => 7, "14d" => 14, "30d" => 30, "all" => nil }.freeze
  # A projected finish (`pace_projected`) carries on at someone's XP a day over the last PACE_DAYS, or since their
  # first XP if that's later, counting at least MIN_PACE_DAYS so one big first day doesn't project a finish.
  PACE_DAYS = 14
  MIN_PACE_DAYS = 3

  # Just below the line: behind, with at least this share of the on-track line.
  CLOSE = 0.5
  # Spread bands (#spread): the edges, as a share of the on-track line, people's XP is sorted between.
  BANDS = [ 0.1, 0.25, 0.5, 0.75, 1, 1.5 ].freeze

  # Projects someone is on, as Evolution counts them for the final stage (Project.involving).
  INVOLVES = <<~SQL.squish
    (projects.user_id = users.id
     OR projects.id IN (SELECT project_id FROM project_members WHERE project_members.user_id = users.id)
     OR projects.id IN (SELECT project_id FROM journals WHERE journals.user_id = users.id AND journals.discarded_at IS NULL))
  SQL
  # Whether someone has a project staff approved, as Evolution asks for the final stage.
  APPROVED_PROJECT = "EXISTS (SELECT 1 FROM projects WHERE projects.discarded_at IS NULL AND projects.approved_at IS NOT NULL AND #{INVOLVES})"
  # When the first of them was approved.
  FIRST_APPROVAL = "(SELECT MIN(projects.approved_at) FROM projects WHERE projects.discarded_at IS NULL AND #{INVOLVES})"
  # When someone wrote their first journal, which made them a builder (QualifyingStats::BUILDER).
  FIRST_JOURNAL = "(SELECT MIN(journals.created_at) FROM journals WHERE journals.user_id = users.id AND journals.discarded_at IS NULL)"

  module_function

  def today(now = Time.current) = now.in_time_zone(ProgramStats::ZONE).to_date
  def deadline = DailyGoal::DEADLINE.to_date
  def goal_xp = Evolution::STAGE_XP.last

  # The end of each of the race's weeks, and the deadline.
  def checkpoints = week_ends | [ deadline ]

  # The Sundays the race's full weeks end on, which is when Lulu's bonuses land on the line.
  def week_ends = (TeamRace::START + 6).step(deadline, 7).to_a

  # This week's checkpoint: the Sunday ahead, or the deadline in its last week.
  def checkpoint(day) = [ Week.of(day).finish, deadline ].min

  # The hours a day the on-track line stands for.
  def hours_per_day(pet) = (goal_xp - bonus_xp(pet, race_days)).fdiv(hourly_xp(pet, race_days, TeamRace::START))

  # The hours the on-track line spends from the race's first day to the deadline, for the XP.
  def line_hours(pet) = (hours_per_day(pet) * race_days.count).round

  # XP on track by the end of `day`.
  def on_track_xp(pet, day)
    days = TeamRace::START..[ day, deadline ].min
    (hours_per_day(pet) * hourly_xp(pet, days, TeamRace::START) + bonus_xp(pet, days)).round
  end

  # The least XP that is just below the line (CLOSE) at the end of `day`.
  def close_xp(pet, day) = (on_track_xp(pet, day) * CLOSE).ceil

  # Each team's lines for `day`, judged at the end of the day before like #status_sql, to say what each status means.
  def lines(day) = User::PETS.index_with { { on_track: on_track_xp(it, day - 1), close: close_xp(it, day - 1) } }

  # Less than this at the end of `day` and the rest takes more than OFF_TRACK_HOURS a day, for a Sami streak at
  # `multiplier` then.
  def off_track_xp(pet, day, multiplier = 1)
    days = (day + 1)..deadline
    [ goal_xp - (OFF_TRACK_HOURS * hourly_xp(pet, days, days.first, multiplier) + bonus_xp(pet, days)).round, 0 ].max
  end

  # Where each person stands on `day`, in SQL over users: qualified, not started (no XP), then against the lines, Sami's
  # off-track line for the multiplier they have (one an admin set off the steps counts as 1).
  def status_sql(day)
    off_track = lambda do |pet|
      next off_track_xp(pet, day - 1) unless pet == "sami"

      "CASE users.xp_multiplier #{Team::Sami.multipliers.map { "WHEN #{it.to_f} THEN #{off_track_xp(pet, day - 1, it)}" }.join(" ")} ELSE #{off_track_xp(pet, day - 1)} END"
    end
    <<~SQL.squish
      CASE WHEN users.xp >= #{goal_xp} AND #{APPROVED_PROJECT} THEN 'qualified'
           WHEN users.xp <= 0 THEN 'not_started'
           WHEN users.xp >= #{by_pet { on_track_xp(it, day - 1) }} THEN 'on_track'
           WHEN users.xp >= #{by_pet(&off_track)} THEN 'behind'
           ELSE 'off_track' END
    SQL
  end

  # The XP someone will have at the deadline if they carry on at their pace over the last PACE_DAYS up to `day`.
  def projected_sql(day)
    ledger = "FROM xp_entries WHERE xp_entries.user_id = users.id AND xp_entries.discarded_at IS NULL"
    recent = "SELECT COALESCE(SUM(amount), 0) #{ledger} AND xp_entries.day > '#{(day - PACE_DAYS).iso8601}'"
    over = "LEAST(#{PACE_DAYS}, GREATEST(#{MIN_PACE_DAYS}, DATE '#{day.iso8601}' - (SELECT MIN(day) #{ledger}) + 1))"
    "(users.xp + ROUND((#{recent}) * #{[ deadline - day, 0 ].max}.0 / #{over}))::integer"
  end

  # `people` with their status as `pace_status` and projected finish as `pace_projected`, to filter, group and order by
  # like columns. The outer select is spelled out because User's ignored_columns otherwise make Rails list only its own
  # columns, dropping them.
  def with_status(people, day)
    User.from(people.select("users.*, (#{status_sql(day)}) AS pace_status, (#{projected_sql(day)}) AS pace_projected"), :users).select("users.*")
  end

  # Funnel steps (ProgramStats::FUNNEL) for each checkpoint, each counting people with their team's XP for it and
  # carrying its day, then those who qualified.
  def funnel_steps
    checkpoints.map do |at|
      xp = User::PETS.index_with { on_track_xp(it, at) }
      [ "pace_#{at.iso8601}", "#{at.strftime("%b %-d")}: #{xp.map { |pet, needed| "#{pet.capitalize} #{needed}" }.join(" · ")} XP",
        "users.xp >= CASE users.pet #{xp.map { |pet, needed| "WHEN '#{pet}' THEN #{needed}" }.join(" ")} END", at ]
    end << [ "qualified", "Qualified", "users.xp >= #{goal_xp} AND #{APPROVED_PROJECT}" ]
  end

  # How many of `people` stood where at the end of each of the race's days before `day`, from the XP ledger: their XP
  # made by then, a project approved by then, and for Sami the multiplier of their last journal by then. The same
  # rules as #status_sql, so the last point is where everyone stood when today began, before today's XP. `close` counts
  # those behind who are just below the line, `reached` everyone with the final stage's XP, approved project or not, and
  # `bands` how many were in each of #spread's bands that day. `moves` is, for each of RANGES, how many moved up a
  # status (RANK) and how many slipped between the end of its first day and the end of the last. All of it twice: for
  # everyone, and for the builders of each day (their first journal written by its end).
  def history(people, day)
    days = TeamRace::START..[ day - 1, deadline ].min
    return { all: { days: [], moves: {} }, builders: { days: [], moves: {} } } if days.none?

    people = people.pluck(:id, :pet, Arel.sql(FIRST_APPROVAL), Arel.sql(FIRST_JOURNAL))
      .to_h { |id, pet, approved, journaled| [ id, [ pet, approved && today(approved), journaled && today(journaled) ] ] }
    entries = XpEntry.kept.where(user_id: people.keys, day: ..days.last).group(:user_id, :day).order(:day)
      .pluck(:user_id, :day, Arel.sql("SUM(amount)"), Arel.sql("MAX(multiplier) FILTER (WHERE kind = 'journal')"))
    xp = Hash.new(0)
    multiplier = Hash.new(1)
    multipliers = Team::Sami.multipliers
    standing = Hash.new { |all, id| all[id] = {} }
    builder_since = people.transform_values(&:last)
    tally = { all: [], builders: [] }

    days.each do |at|
      while entries.first && entries.first[1] <= at
        user_id, _, amount, made_at = entries.shift
        xp[user_id] += amount
        multiplier[user_id] = made_at if made_at
      end
      on_track = User::PETS.index_with { on_track_xp(it, at) }
      off_track = Hash.new { |lines, (pet, rate)| lines[[ pet, rate ]] = off_track_xp(pet, at, rate) }
      close = User::PETS.index_with { close_xp(it, at) }
      counts = { all: Hash.new(0), builders: Hash.new(0) }
      bands = { all: Array.new(BANDS.size + 2, 0), builders: Array.new(BANDS.size + 2, 0) }
      people.each do |id, (pet, approved, journaled)|
        rate = pet == "sami" && multipliers.include?(multiplier[id]) ? multiplier[id] : 1
        status = status(xp[id], qualified: approved.present? && approved <= at, on_track: on_track[pet], off_track: off_track[[ pet, rate ]])
        standing[id][at] = status
        [ :all, (:builders if journaled && journaled <= at) ].compact.each do |group|
          counts[group][status] += 1
          counts[group]["close"] += 1 if status == "behind" && xp[id] >= close[pet]
          counts[group]["reached"] += 1 if xp[id] >= goal_xp
          bands[group][band(xp[id], on_track[pet])] += 1
        end
      end
      tally.each do |group, points|
        points << { date: at.iso8601, **STATUSES.index_with { counts[group][it] }, close: counts[group]["close"], reached: counts[group]["reached"], bands: bands[group] }
      end
    end

    tally.to_h do |group, points|
      who = group == :all ? standing : standing.select { |id, _| builder_since[id]&.<=(days.last) }
      [ group, { days: points, moves: RANGES.transform_values { moves(who, [ days.first, day - (it || days.count) ].max, days.last) } } ]
    end
  end

  # How many moved up a status and how many slipped between the ends of `from` and `to`; for builders, starting counts
  # as moving up from not started.
  def moves(standing, from, to)
    changes = standing.each_value.map { RANK.index(it[to]) <=> RANK.index(it[from]) }
    { up: changes.count(1), down: changes.count(-1) }
  end

  # How many of `people`, and of the builders among them, have XP in each band around their team's on-track line on
  # `day` (BANDS), as shares of it, lowest first: no XP at all (from nil), then up to the top band (to nil). The SQL
  # twin of #band.
  def spread(people, day)
    line = by_pet { [ on_track_xp(it, day - 1), 1 ].max }
    band = "CASE WHEN users.xp <= 0 THEN -1 ELSE width_bucket(users.xp::numeric / #{line}, ARRAY#{BANDS}::numeric[]) END"
    builders = "COUNT(*) FILTER (WHERE #{QualifyingStats::BUILDER})"
    counts = people.group(Arel.sql(band)).pluck(Arel.sql(band), Arel.sql("COUNT(*)"), Arel.sql(builders)).to_h { [ it[0], it.drop(1) ] }
    edges = [ [ nil, 0 ], *(0..BANDS.size).map { [ [ 0, *BANDS ][it], BANDS[it] ] } ]
    { all: 0, builders: 1 }.transform_values do |column|
      edges.each_with_index.map { |(from, to), i| { from:, to:, count: counts.fetch(i - 1, [ 0, 0 ])[column] } }
    end
  end

  # Where `xp` falls in #spread's list of bands against an on-track line of `line`.
  def band(xp, line) = xp <= 0 ? 0 : 1 + BANDS.count { xp.fdiv([ line, 1 ].max) >= it }

  def status(xp, qualified:, on_track:, off_track:)
    if xp >= goal_xp && qualified then "qualified"
    elsif xp <= 0 then "not_started"
    elsif xp >= on_track then "on_track"
    elsif xp >= off_track then "behind"
    else "off_track"
    end
  end

  # A value for each team in SQL over users, from the block's for a pet.
  def by_pet = "CASE users.pet #{User::PETS.map { "WHEN '#{it}' THEN #{yield it}" }.join(" ")} END"

  def race_days = TeamRace::START..deadline

  # XP an hour a day earns over `days`, with a Sami streak at `multiplier` in the week of `from` that rises every week.
  def hourly_xp(pet, days, from, multiplier = 1)
    days.sum do |day|
      XpEntry::PER_HOUR * (pet == "sami" ? [ multiplier + Team::Sami::STEP * ((Week.of(day).start - Week.of(from).start) / 7), Team::Sami::MAX_MULTIPLIER ].min : 1)
    end
  end

  # Lulu's bonuses for the race's weeks that end during `days`.
  def bonus_xp(pet, days) = pet == "lulu" ? week_ends.count { days.cover?(it) } * Team::Lulu::WEEKLY_BONUS : 0
end
