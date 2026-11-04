# A reviewer's read of a project's journals partway through (journal review, /admin/journal-reviews). Not the
# design review (SubmissionReview), and it changes no hours: it checks the journals are good enough and tells the
# team what to do better. The feedback goes to the project's Slack thread and its page.
#
# The team is sent the feedback either way; whether it was approved or a "check back" is for reviewers only, and
# only decides when the project comes back (ProgressStatus): a check back, which takes feedback, brings it back with
# their next journal of CHECK_BACK_MIN_MINUTES or more. The feedback is Markdown, shown on the site and turned into
# Slack's own formatting for Slack (SlackMessages.mrkdwn). Notes on particular journals are for reviewers only.
# `checks`, the to-dos (ReviewTodo) and XP holds (ProgressXpHold) are what older reviews did; new ones make none.
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
  # `journal_notes` maps a journal's public id to a note on it; blank ones are dropped.
  def self.decide(status, reviewer:, verdict:, feedback: nil, journal_notes: {})
    review = new(project: status.project, reviewer:, verdict: verdict.to_s, feedback: feedback.to_s.strip.presence,
      journal_notes: verdict.to_s == "dismissed" ? {} : journal_notes.to_h.to_h { |id, note| [ id.to_s, note.to_s.strip ] }.compact_blank)
    review.errors.add(:base, "You can't review a project you're on") if status.project.on_team?(reviewer)
    return review if review.errors.any? || review.invalid?

    status.with_lock do
      next review.errors.add(:base, "It isn't waiting for a review any more") unless status.due? && !status.flagged?
      next review.errors.add(:base, "Someone else is reviewing this") if status.held_by_someone_else?(reviewer)
      next review.errors.add(:verdict, "dismiss is only for a check back") if review.verdict == "dismissed" && status.due_reason != "check_back"

      review.update!(due_reason: status.due_reason, due_since: status.due_since, logged_minutes: status.logged_minutes)
      status.decided(review)
    end
    review
  end

  # Approvals and check backs send the team the feedback; a dismissal is the reviewers' own business.
  def sent? = verdict != "dismissed"

  private

  def journal_notes_fit
    return if journal_notes.blank?

    errors.add(:journal_notes, "are each at most #{MAX_JOURNAL_NOTE} characters") if journal_notes.values.any? { it.length > MAX_JOURNAL_NOTE }
    known = Journal.where_public_ids(journal_notes.keys).where(project:).kept.count
    errors.add(:journal_notes, "can only be on this project's journals") if known != journal_notes.size
  end
end
