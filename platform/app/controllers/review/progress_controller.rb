# Journal review (ProgressReview): the queue of projects whose journals are due a read, and the page a reviewer
# reads them on. Works like design review: Next claims the oldest for you, deciding opens the one after.
class Review::ProgressController < Review::ApplicationController
  include DeferredTable

  TABS = %w[queue mine decided].freeze
  # How far back the queue page's "reviews take about…" looks.
  TURNAROUND_OVER = 7.days
  NOTICES = { "approved" => "feedback sent", "check_back" => "it comes back after their next journal of #{ProgressStatus::CHECK_BACK_MIN_MINUTES}+ min", "dismissed" => "waiting for one more journal" }.freeze

  def index
    tab = TABS.include?(params[:tab]) ? params[:tab] : "queue"
    reason = params[:reason].presence_in(ProgressStatus::DUE_REASONS.keys)
    statuses = policy_scope([ :review, ProgressStatus ])
    reviews = ProgressReview.where(project_id: statuses.select(:project_id))

    rows = statuses.queued.then { reason ? it.where(due_reason: reason) : it }.in_queue_order if tab == "queue"

    render inertia: "Review/Progress/Index", props: {
      tab:, reason:, reasons: ProgressStatus::DUE_REASONS, can_add: policy([ :review, ProgressStatus ]).add?,
      ladder: { first_at_minutes: ProgressStatus::FIRST_AT_MINUTES, gaps_minutes: ProgressStatus::GAPS_MINUTES,
                check_back_min_minutes: ProgressStatus::CHECK_BACK_MIN_MINUTES },
      counts: InertiaRails.defer(group: "table") { counts(statuses) },
      **table(tab, rows, reviews)
    }
  end

  # Puts the project a link (or a prj_ id) points at in the queue, for admins.
  def add
    authorize [ :review, ProgressStatus ]
    public_id = params.expect(:link).to_s[/prj_[A-Za-z0-9]+/]
    project = public_id && Project.find_by_public_id(public_id)
    return redirect_to(journal_review_root_path, alert: "That isn't a link to a project") unless project

    problem = ProgressStatus.add(project, by: true_user)
    return redirect_to(journal_review_root_path, alert: "#{project.title}: #{problem}.") if problem

    redirect_to journal_review_root_path, notice: "#{project.title} is at the front of the queue."
  end

  # Claims the next project for the reviewer and opens it. `skip` lists ones they passed over this session.
  def next
    authorize [ :review, ProgressStatus ]
    status = ProgressStatus.next_for(true_user, skip: Project.where_public_ids(skipped).select(:id))
    return redirect_to(journal_review_root_path, notice: "Nothing left in the queue. Nice work!") unless status

    status.claim(true_user)
    redirect_to journal_review_project_path(status.project, skip: skipped.join(",").presence)
  end

  def show
    status = Project.find_by_public_id(params[:id])&.progress_status
    # A project deleted for good (or an old link to one) sends the reviewer back to the queue rather than a 404.
    return skip_authorization && redirect_to(journal_review_root_path, alert: "That project isn't in journal review any more.") if status.nil?

    authorize [ :review, status ]
    claimed = policy([ :review, status ]).claim? && status.claim(true_user)
    status.reload if claimed

    policy = policy([ :review, status ])
    can = { decide: policy.decide? && claimed, take_over: policy.decide? && !claimed, flag: policy.flag?, unflag: policy.unflag?,
            star: policy.star?, dismiss: policy.decide? && claimed && status.due_reason == "check_back", own: status.project.on_team?(true_user) }
    render inertia: "Review/Progress/Show", props: ProgressPageProps.new(status, claimed:, can:).props.merge(
      skip: skipped.join(","))
  end

  def update
    status = find_status
    authorize [ :review, status ], :decide?
    fields = params.expect(review: [ :verdict, :feedback, journal_notes: {} ])
    review = ProgressReview.decide(status, reviewer: true_user, verdict: fields[:verdict], feedback: fields[:feedback],
      journal_notes: fields[:journal_notes]&.to_unsafe_h || {})
    if review.persisted?
      redirect_to journal_review_next_path(skip: skipped.join(",").presence), notice: "#{status.project.title}: #{NOTICES.fetch(review.verdict)}."
    else
      redirect_back fallback_location: journal_review_project_path(status.project), inertia: { errors: review.errors.to_hash(true).transform_values(&:to_sentence) }
    end
  end

  # Keeps the claim while the page is open. `held` is false once it can't be: someone else took it, or it was flagged
  # or stopped being due, so the page warns the reviewer instead of losing the review on send.
  def heartbeat
    status = find_status
    authorize [ :review, status ], :show?
    render json: { held: policy([ :review, status ]).claim? && status.claim(true_user) }
  end

  def take_over
    status = find_status
    authorize [ :review, status ], :decide?
    status.take_over(true_user)
    redirect_to journal_review_project_path(status.project, skip: skipped.join(",").presence), notice: "It's yours now."
  end

  # Skip: lets go of it and opens the next one.
  def release
    status = find_status
    authorize [ :review, status ], :show?
    status.release(true_user)
    redirect_to journal_review_next_path(skip: [ *skipped, status.project.public_id ].uniq.join(","))
  end

  def flag
    status = find_status
    authorize [ :review, status ]
    reason = params.expect(:reason).to_s.strip
    return redirect_back(fallback_location: journal_review_project_path(status.project), alert: "Say why it's flagged") if reason.blank?

    status.update!(flagged_at: Time.current, flag_reason: reason, flagged_by: true_user, claimed_by: nil, claim_expires_at: nil)
    status.project.reviewer_notes.create!(user: true_user, body: "Flagged for AI in journal review: #{reason}")
    ReportProgressFlagJob.perform_later(status)
    redirect_to journal_review_next_path(skip: skipped.join(",").presence), notice: "Flagged for AI. It's out of the queue until an admin looks at it."
  end

  def unflag
    status = find_status
    authorize [ :review, status ]
    status.update!(flagged_at: nil, flag_reason: nil, flagged_by: nil)
    status.project.reviewer_notes.create!(user: true_user, body: "AI flag cleared in journal review")
    redirect_to journal_review_project_path(status.project), notice: status.due? ? "Back in the queue." : "Flag cleared."
  end

  def star
    status = find_status
    authorize [ :review, status ]
    status.update!(starred_at: Time.current, starred_by: true_user)
    redirect_back fallback_location: journal_review_project_path(status.project)
  end

  def unstar
    status = find_status
    authorize [ :review, status ], :star?
    status.update!(starred_at: nil, starred_by: nil)
    redirect_back fallback_location: journal_review_project_path(status.project)
  end

  private

  def reviewer?(user) = user.reviews_journals?

  # Projects on the queue tab; reviews made on the others.
  def table(tab, rows, reviews)
    return deferred_table(rows.includes(:claimed_by, :flagged_by, :starred_by, project: :user), ProgressRowSerializer, :projects) if rows

    reviews = reviews.where(reviewer: true_user) if tab == "mine"
    deferred_table(reviews.newest_first.includes(:reviewer, :project), ProgressReviewRowSerializer, :reviews)
  end
  def find_status = ProgressStatus.find_by!(project: Project.find_by_public_id!(params[:id]))
  def skipped = params[:skip].to_s.split(",").grep(/\Aprj_\w+\z/).first(50)

  def counts(statuses)
    queued = statuses.queued
    recent = ProgressReview.reviews.where(created_at: TURNAROUND_OVER.ago..).where.not(due_since: nil)
    { queue: queued.count, by_reason: queued.group(:due_reason).count, mine: ProgressReview.where(reviewer: true_user).count,
      oldest: queued.minimum(:due_since), reviewed_recently: recent.count,
      average_wait_seconds: recent.average(Arel.sql("EXTRACT(EPOCH FROM progress_reviews.created_at - progress_reviews.due_since)"))&.round }
  end
end
