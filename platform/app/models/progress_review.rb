# A reviewer's read of a project's journals partway through (journal review, /admin/journal-reviews). Not the
# design review (SubmissionReview), and it changes no hours: it checks the journals are good enough and tells the
# team what to do better. The feedback goes to the project's Slack thread and its page.
#
# "Check back" takes feedback and something to fix. The feedback is Markdown, shown on the site and turned into
# Slack's own formatting for Slack (SlackMessages.mrkdwn). Notes on particular journals are for reviewers only.
# `checks` holds the boxes older reviews ticked; reviews no longer tick any. The first check back in a row is a
# warning; a second one in a row holds XP back until it's fixed (ProgressXpHold).
# "Dismissed" isn't a review: it puts a check back off until one more journal comes in, with nothing sent.
# ProgressStatus works out when the project comes back.
# == Schema Information
#
# Table name: progress_reviews
#
#  id             :bigint           not null, primary key
#  checks         :jsonb            not null
#  due_reason     :string
#  due_since      :datetime
#  feedback       :text
#  journal_notes  :jsonb            not null
#  logged_minutes :integer          not null
#  verdict        :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  project_id     :bigint           not null
#  reviewer_id    :bigint
#
# Indexes
#
#  index_progress_reviews_on_created_at              (created_at)
#  index_progress_reviews_on_project_id              (project_id)
#  index_progress_reviews_on_project_id_and_verdict  (project_id,verdict)
#  index_progress_reviews_on_reviewer_id             (reviewer_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#
class ProgressReview < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :prv
  has_paper_trail

  VERDICTS = %w[approved check_back dismissed].freeze
  MAX_FEEDBACK = 5_000
  # How much of the XP a person's journals earned since the last review a second check back in a row holds until it's
  # fixed (ProgressXpHold).
  XP_HELD_SHARE = 0.5
  MAX_JOURNAL_NOTE = 1_000

  belongs_to :project
  belongs_to :reviewer, class_name: "User", optional: true
  has_many :review_todos, -> { ordered }, dependent: :delete_all, inverse_of: :progress_review
  has_many :progress_xp_holds, dependent: :restrict_with_error
  has_many :released_xp_holds, class_name: "ProgressXpHold", foreign_key: :released_by_review_id, inverse_of: :released_by_review, dependent: :restrict_with_error

  validates :verdict, inclusion: { in: VERDICTS }
  validates :feedback, length: { maximum: MAX_FEEDBACK }
  validates :feedback, presence: { message: "is needed so they know what to change" }, if: -> { verdict == "check_back" }
  validate :journal_notes_fit

  scope :reviews, -> { where.not(verdict: "dismissed") }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  after_create_commit -> { ProgressReviewedJob.perform_later(self) }, if: :sent?

  # Makes the decision on `status`'s project for `reviewer`, or returns an unsaved review whose errors say why not.
  # `journal_notes` maps a journal's public id to a note on it; blank ones are dropped. A check back adds `todos` (what
  # to fix) and reopens the to-dos in `reopen` (public ids) the team ticked but didn't really fix, and has to leave at
  # least one open; an approval resolves them all.
  def self.decide(status, reviewer:, verdict:, feedback: nil, journal_notes: {}, todos: [], reopen: [])
    review = new(project: status.project, reviewer:, verdict: verdict.to_s, feedback: feedback.to_s.strip.presence,
      journal_notes: verdict.to_s == "dismissed" ? {} : journal_notes.to_h.to_h { |id, note| [ id.to_s, note.to_s.strip ] }.compact_blank)
    review.errors.add(:base, "You can't review a project you're on") if status.project.on_team?(reviewer)
    todos = review.verdict == "check_back" ? Array(todos).map { it.to_s.strip }.compact_blank : []
    reopen = review.verdict == "check_back" ? ReviewTodo.where_public_ids(Array(reopen)).where(project: status.project).unresolved.to_a : []
    review.check_todos(todos, reopen) if review.verdict == "check_back"
    return review if review.errors.any? || review.invalid?

    status.with_lock do
      next review.errors.add(:base, "It isn't waiting for a review any more") unless status.due? && !status.flagged?
      next review.errors.add(:base, "Someone else is reviewing this") if status.held_by_someone_else?(reviewer)
      next review.errors.add(:verdict, "dismiss is only for a check back") if review.verdict == "dismissed" && status.due_reason != "check_back"

      since = status.last_reviewed_at
      review.update!(due_reason: status.due_reason, due_since: status.due_since, logged_minutes: status.logged_minutes)
      review.follow_up(todos:, reopen:, since:)
      status.decided(review)
    end
    review
  end

  # Approvals and check backs go to the team; a dismissal is the reviewers' own business.
  def sent? = verdict != "dismissed"

  # A check back straight after an approval (or as the first review) only warns; one after another check back holds
  # XP. Dismissals don't count either way.
  def warning?
    verdict == "check_back" && project.progress_reviews.reviews.where(id: ...id).newest_first.pick(:verdict) != "check_back"
  end

  # Whether this check back warned that the next one holds XP: not once the design is submitted, when nothing is held.
  def warns_of_hold? = warning? && !ProgressStatus.submitted?(project)

  # A check back needs something left to fix: a new to-do, one it reopens, or one still open and not yet ticked.
  def check_todos(todos, reopen)
    errors.add(:todos, "are each at most #{ReviewTodo::MAX_BODY} characters") if todos.any? { it.length > ReviewTodo::MAX_BODY }
    errors.add(:todos, "can be at most #{ReviewTodo::MAX_PER_REVIEW} at once") if todos.size > ReviewTodo::MAX_PER_REVIEW
    return if todos.any? || reopen.any? || ReviewTodo.where(project:).unresolved.where(done_at: nil).exists?

    errors.add(:todos, "need at least one thing to fix for a check back")
  end

  # What a decision does besides moving the queue: a check back adds its to-dos, reopens the ones it names and, when
  # it's the second in a row, holds XP back (not once the design is submitted: there's nothing left to journal); an
  # approval resolves every to-do and gives back what was held.
  def follow_up(todos:, reopen:, since:)
    case verdict
    when "check_back"
      ReviewTodo.where(id: reopen.map(&:id)).update_all(done_at: nil, done_by_id: nil, updated_at: Time.current)
      todos.each_with_index { |body, i| review_todos.create!(project:, body:, position: i) }
      ProgressXpHold.hold_for(self, since:) unless warning? || ProgressStatus.submitted?(project)
    when "approved"
      ReviewTodo.where(project:).unresolved.update_all(resolved_at: Time.current, updated_at: Time.current)
      ProgressXpHold.release_all(project, by: self)
    end
  end

  private

  def journal_notes_fit
    return if journal_notes.blank?

    errors.add(:journal_notes, "are each at most #{MAX_JOURNAL_NOTE} characters") if journal_notes.values.any? { it.length > MAX_JOURNAL_NOTE }
    known = Journal.where_public_ids(journal_notes.keys).where(project:).kept.count
    errors.add(:journal_notes, "can only be on this project's journals") if known != journal_notes.size
  end
end
