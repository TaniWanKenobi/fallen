# Where a project stands in journal review (ProgressReview): whether it's waiting for a reviewer and why, how much
# logged time brings it back after an approval, who is reviewing it now, and the AI flag and star reviewers give it.
# A row is made the first time a project reaches the queue. `refresh` works out whether it's due from its journals,
# and runs whenever their hours change (ProgressRefreshJob) or the project is submitted.
#
# The rules:
# - Only hours journaled on Fallen count (Journal.written_here): a transfer's hours were logged in another program,
#   so a transferred project is tracked from the transfer on.
# - A project first comes up at FIRST_AT_MINUTES logged, so beginners hear about mistakes before they repeat them for
#   weeks.
# - Approving it brings it back after GAPS_MINUTES more: the first gap after the first approval, the next after the
#   second, and the last one for every approval after that.
# - "Check back" brings it back with the next journal that has hours. A reviewer can dismiss a check back to wait
#   for one more.
# - The team can ask for a review themselves (request), at most once every REQUEST_COOLDOWN, and it goes to the front.
#   An admin can add any project by its link (add), whatever its hours or submission, and it goes to the front too.
# - Once the design is submitted it's done, unless it has never had a journal review or a check back from before it
#   was submitted is still open: then it gets one last look.
# - Flagged for AI, it stays out of the queue until an admin clears the flag.
# == Schema Information
#
# Table name: progress_statuses
#
#  id               :bigint           not null, primary key
#  added_at         :datetime
#  approvals_count  :integer          default(0), not null
#  claim_expires_at :datetime
#  due_reason       :string
#  due_since        :datetime
#  flag_reason      :text
#  flagged_at       :datetime
#  last_reviewed_at :datetime
#  logged_minutes   :integer          default(0), not null
#  next_at_minutes  :integer          not null
#  request_note     :text
#  requested_at     :datetime
#  reviews_count    :integer          default(0), not null
#  starred_at       :datetime
#  waiting_since    :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  added_by_id      :bigint
#  claimed_by_id    :bigint
#  flagged_by_id    :bigint
#  project_id       :bigint           not null
#  requested_by_id  :bigint
#  starred_by_id    :bigint
#
# Indexes
#
#  index_progress_statuses_on_added_by_id      (added_by_id)
#  index_progress_statuses_on_claimed_by_id    (claimed_by_id)
#  index_progress_statuses_on_flagged_at       (flagged_at) WHERE (flagged_at IS NOT NULL)
#  index_progress_statuses_on_flagged_by_id    (flagged_by_id)
#  index_progress_statuses_on_project_id       (project_id) UNIQUE
#  index_progress_statuses_on_requested_by_id  (requested_by_id)
#  index_progress_statuses_on_starred_at       (starred_at) WHERE (starred_at IS NOT NULL)
#  index_progress_statuses_on_starred_by_id    (starred_by_id)
#  index_progress_statuses_queued              (due_since) WHERE ((due_since IS NOT NULL) AND (flagged_at IS NULL))
#  index_progress_statuses_queued_by_reason    (due_reason,due_since) WHERE ((due_since IS NOT NULL) AND (flagged_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (added_by_id => users.id)
#  fk_rails_...  (claimed_by_id => users.id)
#  fk_rails_...  (flagged_by_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (requested_by_id => users.id)
#  fk_rails_...  (starred_by_id => users.id)
#
class ProgressStatus < ApplicationRecord
  has_paper_trail

  # 10h at launch, while the backlog is worked through; meant to come down (to 4h) once the queue keeps up.
  FIRST_AT_MINUTES = 10 * 60
  GAPS_MINUTES = [ 6, 10, 40, 80, 100 ].map { it * 60 }.freeze
  CLAIM_FOR = 15.minutes
  # Asking for a review: there has to be something to read, and not more often than this.
  REQUEST_MIN_MINUTES = 60
  REQUEST_COOLDOWN = 3.days
  MAX_REQUEST_NOTE = 1_000
  DUE_REASONS = {
    "requested" => "They asked for one",
    "added" => "Added by an admin",
    "first" => "First review",
    "approved" => "More hours since approval",
    "check_back" => "Check back",
    "submitted" => "Submitted, never reviewed"
  }.freeze

  belongs_to :project
  belongs_to :claimed_by, class_name: "User", optional: true
  belongs_to :flagged_by, class_name: "User", optional: true
  belongs_to :starred_by, class_name: "User", optional: true
  belongs_to :requested_by, class_name: "User", optional: true
  belongs_to :added_by, class_name: "User", optional: true
  has_many :progress_reviews, primary_key: :project_id, foreign_key: :project_id, inverse_of: false

  validates :due_reason, inclusion: { in: DUE_REASONS.keys }, allow_nil: true
  validates :flag_reason, length: { maximum: 2_000 }
  validates :request_note, length: { maximum: MAX_REQUEST_NOTE }

  scope :queued, -> { where.not(due_since: nil).where(flagged_at: nil) }
  scope :flagged, -> { where.not(flagged_at: nil) }
  scope :starred, -> { where.not(starred_at: nil) }
  # Ones the team asked for or an admin added first, then whoever has waited longest.
  scope :in_queue_order, -> { order(Arel.sql("CASE WHEN progress_statuses.due_reason IN ('requested', 'added') THEN 0 ELSE 1 END"), :due_since, :id) }
  scope :claimable, -> { where("progress_statuses.claimed_by_id IS NULL OR progress_statuses.claim_expires_at < ?", Time.current) }

  def self.gap_after(approvals) = GAPS_MINUTES[(approvals - 1).clamp(0, GAPS_MINUTES.size - 1)]

  # Works out whether the project is due now and saves it if anything changed. A project that has never been due
  # gets no row until it is.
  def self.refresh(project)
    status = find_or_build(project)
    status.persisted? ? status.with_lock { status.recompute } : status.recompute
    status
  rescue ActiveRecord::RecordNotUnique
    retry # Someone else made the row first: start again from theirs.
  end

  # The project the reviewer should look at next: the one they hold, else the one waiting longest that isn't their
  # own team's, held by someone else, or skipped.
  def self.next_for(reviewer, skip: [])
    held = queued.find_by(claimed_by: reviewer, claim_expires_at: Time.current..)
    return held if held

    queued.claimable.where.not(project_id: Project.teamed_with(reviewer).select(:id))
      .where.not(project_id: skip).in_queue_order.first
  end

  # Why the team can't ask for a review now, or nil if they can.
  def self.request_blocker(project)
    status = find_by(project:)
    return "It's already waiting for a review" if status&.due? || status&.flagged?
    if status&.requested_at&.after?(REQUEST_COOLDOWN.ago)
      return "You can ask again in #{ActionController::Base.helpers.distance_of_time_in_words_to_now(status.requested_at + REQUEST_COOLDOWN)}"
    end
    return "Journal review is done once the design is submitted" if submitted?(project) && status&.reviews_count.to_i.positive?
    return "Log at least #{REQUEST_MIN_MINUTES / 60} hour of journals first" if counted_journals(project).sum(:duration_minutes).to_i < REQUEST_MIN_MINUTES

    nil
  end

  # Puts the project at the front of the queue for `user`, who is on its team, with what they'd like looked at.
  def self.request(project, user:, note: nil)
    status = find_or_build(project)
    status.assign_attributes(requested_at: Time.current, requested_by: user, request_note: note.to_s.strip.presence)
    return status unless status.valid?

    status.recompute
    status
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # Puts the project in the queue for an admin, or returns why not.
  def self.add(project, by:)
    return "That project was deleted" if project.discarded?

    status = find_or_build(project)
    return "It's flagged for AI; clear the flag on its review page instead" if status.flagged?
    return "It's already in the queue" if status.due?

    status.update!(added_at: Time.current, added_by: by)
    status.recompute
    nil
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # A design sent for review that wasn't taken back: from then on journal review is winding down.
  def self.submissions(project) = project.submissions.where.not(status: "withdrawn")
  def self.submitted?(project) = submissions(project).exists?

  # The project's row, or a new one starting at the first threshold. Callers making the first row retry on
  # RecordNotUnique, since two can race to make it (a journal's refresh and a teammate's request).
  # The journals whose hours journal review counts.
  def self.counted_journals(project) = project.journals.kept.written_here

  def self.find_or_build(project) = find_or_initialize_by(project:) { it.next_at_minutes = FIRST_AT_MINUTES }

  # True if the reviewer now holds it. One UPDATE, so two reviewers opening it at once can't both win.
  def claim(reviewer)
    self.class.queued.where(id:).where("claimed_by_id IS NULL OR claimed_by_id = :id OR claim_expires_at < :now", id: reviewer.id, now: Time.current)
      .update_all(claimed_by_id: reviewer.id, claim_expires_at: CLAIM_FOR.from_now, updated_at: Time.current) == 1
  end

  def take_over(reviewer)
    self.class.queued.where(id:).update_all(claimed_by_id: reviewer.id, claim_expires_at: CLAIM_FOR.from_now, updated_at: Time.current) == 1
  end

  def release(reviewer) = self.class.where(id:, claimed_by_id: reviewer.id).update_all(claimed_by_id: nil, claim_expires_at: nil)

  def due? = due_since.present?
  def flagged? = flagged_at.present?
  def starred? = starred_at.present?
  def due_label = DUE_REASONS[due_reason]
  def held_by_someone_else?(reviewer) = claimed_by_id && claimed_by_id != reviewer.id && claim_expires_at&.future?

  # The logged time that brings it back after an approval, or nil while it waits on a journal instead.
  def next_due_minutes = waiting_since ? nil : next_at_minutes

  # Applies a decision (ProgressReview) and works out what's next. Called inside the row's lock.
  def decided(review)
    if review.sent?
      self.reviews_count += 1
      self.last_reviewed_at = review.created_at
    end
    case review.verdict
    when "approved"
      self.approvals_count += 1
      self.next_at_minutes = review.logged_minutes + self.class.gap_after(approvals_count)
      self.waiting_since = nil
    else
      self.waiting_since = review.created_at
    end
    self.due_since = nil
    self.due_reason = nil
    self.claimed_by_id = nil
    self.claim_expires_at = nil
    recompute
  end

  def recompute
    journals = self.class.counted_journals(project)
    self.logged_minutes = journals.sum(:duration_minutes).to_i
    reason = reason_due(journals)
    self.due_since = reason ? due_since || Time.current : nil
    self.due_reason = reason
    save! if changed? && (persisted? || reason)
  end

  private

  def reason_due(journals)
    return nil if project.discarded? || project.user.is_banned? || project.user.discarded?
    return "added" if added_at && (last_reviewed_at.nil? || added_at > last_reviewed_at)
    return "requested" if requested_at && (last_reviewed_at.nil? || requested_at > last_reviewed_at)
    return reason_after_submission if self.class.submitted?(project)
    return (journals.where.not(duration_minutes: nil).exists?([ "journals.created_at > ?", waiting_since ]) ? "check_back" : nil) if waiting_since
    return nil if logged_minutes < next_at_minutes

    reviews_count.zero? ? "first" : "approved"
  end

  # Never reviewed, or a check back from before it was submitted still open: one last look. Otherwise it's done.
  def reason_after_submission
    return "submitted" if reviews_count.zero? && logged_minutes >= FIRST_AT_MINUTES
    return "check_back" if waiting_since && waiting_since < self.class.submissions(project).minimum(:created_at)

    nil
  end
end
