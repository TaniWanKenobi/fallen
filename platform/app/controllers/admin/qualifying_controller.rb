# How many people are on track to qualify by the deadline (QualifyingPace): where everyone stands now and at their
# pace, how that has moved day by day, how far above or below the line they are and through the hours, who is locking
# in, and everyone in a tab (QualifyingStats).
class Admin::QualifyingController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #show authorizes explicitly

  LOCKING_IN_ROWS = 10

  def show
    authorize [ :admin, :qualifying ]
    tab = QualifyingStats::TABS.include?(params[:tab]) ? params[:tab] : QualifyingStats::TABS.first
    today = QualifyingPace.today
    people = QualifyingPace.with_status(User.on_a_team, today)
    lines = QualifyingPace.lines(today).transform_values { it[:on_track] }

    render inertia: "Admin/Qualifying/Show", props: {
      tab:,
      today: today.iso8601,
      deadline: QualifyingPace.deadline.iso8601,
      goal_xp: QualifyingPace.goal_xp,
      xp_per_hour: XpEntry::PER_HOUR,
      off_track_hours: QualifyingPace::OFF_TRACK_HOURS,
      close_share: QualifyingPace::CLOSE,
      quiet_days: QualifyingStats::QUIET_DAYS,
      lines: QualifyingPace.lines(today),
      line_hours: User::PETS.index_with { QualifyingPace.line_hours(it) },
      lock_in: { days: QualifyingStats::LOCK_IN_DAYS, hours: QualifyingStats::LOCK_IN_HOURS },
      summary: InertiaRails.defer(group: "charts") { QualifyingStats.summary(people, today) },
      history: InertiaRails.defer(group: "charts") { QualifyingPace.history(User.on_a_team, today) },
      spread: InertiaRails.defer(group: "charts") { QualifyingPace.spread(User.on_a_team, today) },
      hours_funnel: InertiaRails.defer(group: "charts") { QualifyingStats.hours_funnel(User.on_a_team) },
      locking_in: InertiaRails.defer(group: "locking_in") do
        minutes = QualifyingStats.locked_in(User.on_a_team)
        top = people.where(id: minutes.keys.first(LOCKING_IN_ROWS)).to_a.sort_by { -minutes[it.id] }
        { count: minutes.size, rows: AdminQualifyingRowSerializer.render(top, **row_params(top, lines, today)) }
      end,
      **deferred_table(QualifyingStats.tab(people, tab, today).order(xp: :desc, id: :asc), AdminQualifyingRowSerializer, :rows) { row_params(it, lines, today) }
    }
  end

  private

  def row_params(users, lines, day) = { lines:, day:, **QualifyingStats.journal_activity(users.map(&:id)) }
end
