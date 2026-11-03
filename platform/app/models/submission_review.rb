# One reviewer's decision on a Submission. There is a single review per submission, so it has to be complete:
# every rubric question answered, every journal given the time that counts (cut journal by journal, with a reason),
# every line of the bill of materials approved, adjusted or cut, an internal reason, and feedback for the person
# unless it is a clean approval. Rejecting is for good and only admins do it.
#
# Reviewers claim a submission while they work on it (claim), so two never review one at once; the page keeps the
# claim alive (heartbeat) and it lapses on its own after CLAIM_FOR.
class SubmissionReview
  include ActiveModel::Model

  CLAIM_FOR = 15.minutes
  VERDICTS = %w[approved returned rejected].freeze

  attr_reader :submission, :reviewer, :verdict, :feedback, :internal_reason, :rubric, :journals, :bom

  # The journals a review covers: every one with hours logged on the project before it was submitted.
  def self.journals_for(submission) = submission.project.journals.kept.where.not(duration_minutes: nil).where(created_at: ..submission.created_at)

  # The submission the reviewer should look at next: the one they hold, else the one waiting longest that isn't
  # their own team's, held by someone else, or skipped.
  def self.next_for(reviewer, skip: [])
    held = Submission.queued.find_by(claimed_by: reviewer, claim_expires_at: Time.current..)
    return held if held

    Submission.queued.where("claimed_by_id IS NULL OR claim_expires_at < ?", Time.current)
      .where.not(project_id: Project.teamed_with(reviewer).select(:id))
      .where.not(id: skip).order(:created_at, :id).first
  end

  # True if the reviewer now holds it. One UPDATE, so two reviewers opening it at once can't both win.
  def self.claim(submission, reviewer)
    Submission.queued.where(id: submission.id)
      .where("claimed_by_id IS NULL OR claimed_by_id = :id OR claim_expires_at < :now", id: reviewer.id, now: Time.current)
      .update_all(claimed_by_id: reviewer.id, claim_expires_at: CLAIM_FOR.from_now, updated_at: Time.current) == 1
  end

  # Takes a submission over from whoever holds it, for when they've walked away from an open tab. Their page finds out
  # on its next heartbeat and stops; what they had typed stays in their browser and its last save on the server.
  def self.take_over(submission, reviewer)
    Submission.queued.where(id: submission.id)
      .update_all(claimed_by_id: reviewer.id, claim_expires_at: CLAIM_FOR.from_now, updated_at: Time.current) == 1
  end

  def self.release(submission, reviewer)
    Submission.where(id: submission.id, claimed_by_id: reviewer.id).update_all(claimed_by_id: nil, claim_expires_at: nil)
  end

  def initialize(submission, reviewer:, verdict:, feedback: nil, internal_reason: nil, rubric: {}, journals: {}, bom: {})
    @submission = submission
    @reviewer = reviewer
    @verdict = verdict.to_s
    @feedback = feedback.to_s.strip.presence
    @internal_reason = internal_reason.to_s.strip.presence
    @rubric = rubric.to_h.stringify_keys.slice(*Submission::RUBRIC.keys)
    @journals = journals.to_h.stringify_keys
    @bom = bom.to_h.stringify_keys
  end

  def save
    covered = self.class.journals_for(submission).to_a
    items = submission.bom_items.to_a
    validate_decision(covered, items)
    return false if errors.any?

    submission.with_lock do
      next errors.add(:base, "Someone else already decided this") unless submission.pending?
      next errors.add(:base, "Someone else is reviewing this") if held_by_someone_else?

      covered.each { |journal| record_journal(journal) }
      items.each { |item| record_item(item) }
      submission.update!(status: verdict, reviewer:, rubric:, feedback:, internal_reason:, decided_at: Time.current,
        approved_cents: verdict == "approved" ? items.sum(&:funded_cents) : nil, claimed_by: nil, claim_expires_at: nil,
        review_draft: nil, review_draft_at: nil, review_draft_by: nil)
      GrantPayout.create!(submission:, user: submission.user, amount_cents: submission.approved_cents) if submission.approved? && submission.approved_cents.positive?
    end
    return false if errors.any?

    SubmissionDecidedJob.perform_later(submission)
    GrantPayoutJob.perform_later(submission.grant_payout) if submission.grant_payout && GrantPayout.automatic?
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  private

  def validate_decision(covered, items)
    errors.add(:verdict, "must be approve, return or reject") unless verdict.in?(VERDICTS)
    errors.add(:base, "Only admins can reject") if verdict == "rejected" && !reviewer.admin?
    errors.add(:base, "You can't review a project you're on") if submission.project.on_team?(reviewer)
    errors.add(:rubric, "needs every question answered") unless Submission::RUBRIC.keys.all? { |key| rubric[key].in?(Submission::ANSWERS) }
    errors.add(:internal_reason, "is needed: say why, for the next reviewer") if internal_reason.blank?
    errors.add(:feedback, "is needed so they know what to change") if feedback.blank? && verdict != "approved"
    covered.each do |journal|
      call = journals[journal.public_id]
      next errors.add(:journals, "each need a decision (#{journal.public_id} has none)") unless call

      minutes = Integer(call["approved_minutes"].to_s, exception: false)
      errors.add(:journals, "can't count more time than was logged") if minutes.nil? || minutes.negative? || minutes > journal.duration_minutes
      errors.add(:journals, "need a reason when time is taken off") if minutes && minutes < journal.duration_minutes && !call["reason"].in?(JournalReview::REASONS)
    end
    return unless verdict == "approved"

    items.each do |item|
      call = bom[item.public_id]
      next errors.add(:bom, "each line needs a decision before approving") unless call&.dig("verdict").in?(BomItem::VERDICTS)
      next if call["verdict"] == "approved"

      reasons = call["verdict"] == "cut" ? BomItem::CUT_REASONS : BomItem::ADJUST_REASONS
      if call["verdict"] == "adjusted"
        cents = Integer(call["approved_cents"].to_s, exception: false)
        errors.add(:bom, "adjusted lines need an amount below what was asked") unless cents && cents >= 0 && cents < item.requested_cents
      end
      errors.add(:bom, "lines that are cut or adjusted need a reason") unless call["reason"].in?(reasons)
    end
  end

  def held_by_someone_else? = submission.claimed_by_id && submission.claimed_by_id != reviewer.id && submission.claim_expires_at&.future?

  def record_journal(journal)
    call = journals.fetch(journal.public_id)
    minutes = Integer(call["approved_minutes"].to_s)
    review = submission.journal_reviews.find_or_initialize_by(journal:)
    review.update!(reviewer:, approved_minutes: minutes, reason: minutes < journal.duration_minutes ? call["reason"] : nil, note: call["note"].to_s.strip.presence)
    reviewed = minutes < journal.duration_minutes ? minutes : nil
    return if journal.reviewed_minutes == reviewed

    journal.update_column(:reviewed_minutes, reviewed)
    XpEntry.sync(journal) unless journal.transferred?
  end

  def record_item(item)
    call = bom[item.public_id] or return
    verdict = call["verdict"].presence_in(BomItem::VERDICTS)
    approved = verdict == "adjusted" ? Integer(call["approved_cents"].to_s, exception: false) : nil
    item.update!(verdict:, reason: verdict == "approved" ? nil : call["reason"], approved_cents: approved)
  end
end
