# frozen_string_literal: true

# Everything the journal review page (/admin/journal-reviews/projects/:id) shows, in a fixed number of queries
# whatever the size of the project: the project and team, every journal on it with the evidence for its hours, the
# reviews made before and the reviewers' notes.
class ProgressPageProps
  def initialize(status, claimed:, can:)
    @status = status
    @claimed = claimed
    @can = can
  end

  # Everything but the project and status is a lambda, so a partial reload (the deferred `people`) runs only its own
  # queries. Inertia runs the lambdas in the controller, so they reach this object as `page`.
  def props
    project = @status.project
    page = self
    Project.preload_teams([ project ])
    ActiveRecord::Associations::Preloader.new(records: [ @status ], associations: [ :claimed_by, :flagged_by, :starred_by, *(:requested_by if @status.due_reason == "requested"), *(:added_by if @status.due_reason == "added") ]).call

    {
      project: {
        id: project.public_id, title: project.title, description: project.description, slack_url: project.slack_url,
        team: PersonSerializer.render(project.teammates), created_at: project.created_at, submitted: submitted?
      },
      status: status_props,
      journals: -> { ReviewJournalSerializer.render(page.journals, writing: page.writing_scores(page.journals.map(&:id))) },
      history: -> { ProgressReviewRowSerializer.render(page.history) },
      notes: -> { ReviewerNoteSerializer.render(project.reviewer_notes.includes(:user).order(:created_at, :id)) },
      checks: ProgressReview::CHECKS,
      required_checks: ProgressReview::REQUIRED_CHECKS,
      max_journal_note: ProgressReview::MAX_JOURNAL_NOTE,
      todos: -> { ReviewTodoSerializer.render(project.review_todos.unresolved.ordered.includes(:done_by)) },
      held_xp: -> { ProgressXpHold.where(project:).held.sum(:amount) },
      xp_held_share: ProgressReview::XP_HELD_SHARE,
      # A check back now would hold XP: the last review was one too (ProgressReview#warning?).
      check_back_holds: -> { !page.submitted? && page.history.find(&:sent?)&.verdict == "check_back" },
      max_todo: ReviewTodo::MAX_BODY,
      resources: ProgressReview.resources,
      claimed: @claimed,
      can: @can
    }
  end

  # Loaded once, for whichever props ask.
  def journals = @journals ||= @status.project.journals.kept.order(:created_at, :id).includes(:user, :xp_entry, :lapse_timelapses, images_attachments: :blob).to_a
  def history = @history ||= @status.project.progress_reviews.newest_first.includes(:reviewer).to_a.each { it.project = @status.project }
  def submitted? = @submitted.nil? ? (@submitted = ProgressStatus.submitted?(@status.project)) : @submitted

  # The latest AI share Pangram gave each journal, by id.
  def writing_scores(ids) = WritingCheck.where(journal_id: ids, status: "done").order(:created_at, :id).pluck(:journal_id, :fraction_ai).to_h

  # Each teammate's track record outside this project, so a reviewer pitches feedback to a first-timer differently from
  # someone on their fourth build: their other projects and the journal reviews those had. Three queries for any team.
  def self.people(project)
    team = project.teammates.uniq
    ids = team.map(&:id)
    others = Project.kept.where(user_id: ids).where.not(id: project.id).pluck(:user_id, :id) +
             ProjectMember.joins(:project).merge(Project.kept).where(user_id: ids).where.not(project_id: project.id).pluck(:user_id, :project_id)
    by_person = others.group_by(&:first).transform_values { |rows| rows.map(&:last).uniq }
    verdicts = ProgressReview.reviews.where(project_id: by_person.values.flatten.uniq).group(:project_id, :verdict).count
    team.map do |person|
      projects = by_person.fetch(person.id, [])
      counts = verdicts.select { |(project_id, _), _| projects.include?(project_id) }
      { person: PersonSerializer.render(person), joined_at: person.created_at, other_projects: projects.size,
        approved: counts.sum { |(_, verdict), n| verdict == "approved" ? n : 0 },
        check_backs: counts.sum { |(_, verdict), n| verdict == "check_back" ? n : 0 } }
    end
  end

  private

  def status_props
    s = @status
    {
      due_reason: s.due_reason, due_label: s.due_label, due_since: s.due_since, logged_minutes: s.logged_minutes,
      approvals_count: s.approvals_count, reviews_count: s.reviews_count, next_due_minutes: s.next_due_minutes,
      waiting_since: s.waiting_since, last_reviewed_at: s.last_reviewed_at,
      next_gap_minutes: ProgressStatus.gap_after(s.approvals_count + 1),
      flagged_at: s.flagged_at, flag_reason: s.flag_reason, flagged_by: s.flagged_by && PersonSerializer.render(s.flagged_by),
      starred: s.starred?, starred_by: s.starred_by && PersonSerializer.render(s.starred_by),
      claimed_by: s.claimed_by && PersonSerializer.render(s.claimed_by), claim_expires_at: s.claim_expires_at,
      # What the team asked to have looked at, when they asked for this review.
      request: s.due_reason == "requested" ? { at: s.requested_at, note: s.request_note, by: s.requested_by && PersonSerializer.render(s.requested_by) } : nil,
      added: s.due_reason == "added" ? { at: s.added_at, by: s.added_by && PersonSerializer.render(s.added_by) } : nil
    }
  end
end
