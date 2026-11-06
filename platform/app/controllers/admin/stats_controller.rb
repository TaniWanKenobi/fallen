class Admin::StatsController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #show authorizes explicitly

  def show
    authorize [ :admin, :stats ]
    stats = ProgramStats.new(range: params[:range], from: params[:from], to: params[:to], milestones: true)

    # The panels are in the default deferred group with the sidebar's counts, so they load in one request: a group each
    # was six requests at once on every visit (Sentry's N+1 API call), and a round trip costs more than a panel's queries.
    render inertia: "Admin/Stats/Show", props: {
      range: stats.range,
      **stats.dates,
      ranges: ProgramStats::RANGES.keys,
      active: InertiaRails.defer { stats.active },
      daily: InertiaRails.defer { stats.daily },
      funnel: InertiaRails.defer { stats.funnel },
      sources: InertiaRails.defer { stats.sources },
      writing: InertiaRails.defer { stats.writing }
    }
  end
end
