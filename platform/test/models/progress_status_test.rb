require "test_helper"

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
class ProgressStatusTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @project = projects(:station)
    @reviewer = users(:newcomer)
    @reviewer.update!(roles: %w[user reviewer])
  end

  FIRST = ProgressStatus::FIRST_AT_MINUTES / 60.0

  # Journals are made as transfers so they skip the photo and writing rules and earn no XP of their own (it comes from a
  # ledger entry), then marked as written here, since journal review doesn't count transferred hours.
  def log(hours, at: Time.current)
    @project.journals.kept.update_all(duration_minutes: nil, discarded_at: at)
    add(hours, at:)
  end

  def add(hours, at: Time.current, xp: nil)
    journal = @project.journals.create!(user: @project.user, body: "x" * 2_000, duration_minutes: (hours * 60).round, created_at: at, source: "transfer")
    journal.update_column(:source, "web")
    XpEntry.create!(user: @project.user, kind: "journal", amount: xp, day: at.to_date, source: journal) if xp
    ProgressStatus.refresh(@project)
  end

  def decide(verdict, feedback: "Keep it up", todos: verdict == "check_back" ? [ "Add photos" ] : [], **rest)
    status = @project.reload.progress_status
    review = ProgressReview.decide(status, reviewer: @reviewer, verdict:, feedback:, todos:, checks: ProgressReview::CHECKS.keys.index_with { true }, **rest)
    assert review.persisted?, review.errors.full_messages.to_sentence
    status.reload
  end

  test "comes up early, at the first threshold, not before" do
    log(FIRST - 0.5)
    assert_nil @project.reload.progress_status

    add(0.5)
    status = @project.reload.progress_status
    assert_equal "first", status.due_reason
    assert_equal ProgressStatus::FIRST_AT_MINUTES, status.logged_minutes
  end

  test "each approval waits for a bigger gap, then the last one from then on" do
    log(FIRST)
    seen = []
    6.times do
      status = decide("approved")
      refute status.due?
      seen << status.next_at_minutes - status.logged_minutes
      add((status.next_at_minutes - status.logged_minutes) / 60.0)
      assert_equal "approved", @project.reload.progress_status.due_reason
    end
    assert_equal [ *ProgressStatus::GAPS_MINUTES, ProgressStatus::GAPS_MINUTES.last ], seen
  end

  test "a check back comes back with the next journal that has hours, and a dismissal waits for one more" do
    log(FIRST, at: 3.days.ago)
    status = travel_to(2.days.ago) { decide("check_back") }
    refute status.due?

    journal = @project.journals.create!(user: @project.user, body: "x" * 2_000, source: "transfer", created_at: 1.day.ago)
    journal.update_column(:source, "web")
    refute ProgressStatus.refresh(@project).due?, "a journal without hours doesn't count yet"

    journal.update_column(:duration_minutes, 15)
    status = ProgressStatus.refresh(@project)
    assert_equal "check_back", status.due_reason

    status = decide("dismissed", feedback: nil)
    refute status.due?
    assert_equal 1, status.reviews_count, "a dismissal isn't a review"
    add(0.25, at: 1.second.from_now)
    assert_equal "check_back", @project.reload.progress_status.due_reason
  end

  test "a first check back warns, a second in a row holds back XP, and approving gives it back and resolves the to-dos" do
    user = @project.user
    log(FIRST, at: 2.days.ago)
    status = @project.reload.progress_status
    review = ProgressReview.decide(status, reviewer: @reviewer, verdict: "check_back", feedback: "Hi", checks: {})
    assert review.errors[:todos].any?

    decide("check_back", feedback: "Great sketches!", todos: [ "Say why you picked the BME280", "Add a photo of the wiring" ])
    warning = @project.progress_reviews.order(:id).last
    todos = ReviewTodo.where(project: @project).ordered
    assert_equal [ "Say why you picked the BME280", "Add a photo of the wiring" ], todos.map(&:body)
    assert_empty ProgressXpHold.all, "the first check back only warns"
    assert_match "No XP is held this time", SlackMessages.progress_reviewed_dm(warning, user)[:text]
    thread = SlackMessages.progress_reviewed(warning)[:text]
    assert_match "Great sketches!", thread
    assert_no_match(/BME280|XP/, thread, "what to fix and XP go only to the team's DMs")

    todos.first.mark(true, by: user)
    add(1, at: 1.second.from_now, xp: 40)
    before = user.reload.xp
    decide("check_back", todos: [], reopen: [ todos.first.public_id ])
    refute todos.first.reload.done?, "the reviewer reopened it"
    hold = ProgressXpHold.sole
    assert_equal (40 * ProgressReview::XP_HELD_SHARE).floor, hold.amount
    assert_equal before - hold.amount, user.reload.xp
    assert_match "holding back #{hold.amount} of your XP", SlackMessages.progress_reviewed_dm(hold.progress_review, user)[:text]

    add(1, at: 2.seconds.from_now)
    approval = decide("approved") && @project.progress_reviews.order(:id).last
    assert ReviewTodo.where(project: @project).all?(&:resolved_at)
    assert_equal [ approval ], ProgressXpHold.where(project: @project).map(&:released_by_review).uniq
    assert_equal before, user.reload.xp
  end

  test "deleting the project gives back the XP a check back was holding" do
    user = @project.user
    log(FIRST, at: 2.days.ago)
    travel_to(1.day.ago) { decide("check_back") }
    add(1, xp: 40)
    decide("check_back")
    held = ProgressXpHold.sole
    @project.discard
    assert held.reload.released_at
    assert_nil held.released_by_review
    assert_equal 0, user.xp_entries.kept.where(kind: %w[review_hold review_release]).sum(:amount)
  end

  test "a check back that only reopens earlier to-dos still tells the team what to fix" do
    log(FIRST, at: 2.days.ago)
    travel_to(1.day.ago) { decide("check_back", todos: [ "Add photos" ]) }
    todo = ReviewTodo.sole
    todo.mark(true, by: @project.user)
    add(1)
    review = ProgressReview.decide(@project.reload.progress_status, reviewer: @reviewer, verdict: "check_back", feedback: "Not quite", reopen: [ todo.public_id ])
    assert review.persisted?, review.errors.full_messages.to_sentence
    assert_match "• Add photos", SlackMessages.progress_reviewed_dm(review, @project.user)[:text]
  end

  test "two callers making the first row at once both end up with it" do
    log(FIRST)
    original = ProgressStatus.method(:find_or_build)
    calls = 0
    # The first lookup misses the row, as it would if the other caller made it a moment later.
    ProgressStatus.define_singleton_method(:find_or_build) do |project|
      (calls += 1) == 1 ? ProgressStatus.new(project:, next_at_minutes: ProgressStatus::FIRST_AT_MINUTES) : original.call(project)
    end
    status = ProgressStatus.refresh(@project)
    assert_equal 2, calls, "it tried again after RecordNotUnique"
    assert status.persisted?
    assert_equal 1, ProgressStatus.where(project: @project).count
  ensure
    ProgressStatus.define_singleton_method(:find_or_build, original)
  end

  test "the team can ask for a review: it goes to the front, once every so often" do
    log(FIRST, at: 2.days.ago)
    other = projects(:unlinked)
    other.journals.kept.update_all(duration_minutes: 90)
    assert_nil ProgressStatus.request_blocker(other)
    ProgressStatus.request(other, user: other.user, note: "Is my wiring diagram clear?")
    assert_equal [ other, @project ], ProgressStatus.queued.in_queue_order.map(&:project)
    assert_match "already waiting", ProgressStatus.request_blocker(other)

    status = other.reload.progress_status
    ProgressReview.decide(status, reviewer: @reviewer, verdict: "approved", checks: ProgressReview::CHECKS.keys.index_with { true })
    refute status.reload.due?
    assert_match "ask again", ProgressStatus.request_blocker(other)
    travel(ProgressStatus::REQUEST_COOLDOWN + 1.minute) { assert_nil ProgressStatus.request_blocker(other) }
  end

  test "submitting ends it, unless it was never reviewed or a check back is still open" do
    submit_design(@project)
    log(FIRST + 2)
    assert_equal "submitted", @project.reload.progress_status.due_reason

    decide("approved")
    add(200)
    refute @project.reload.progress_status.due?
  end

  test "a check back from before the submission gets one last look, which holds no XP" do
    @project.journals.kept.update_all(duration_minutes: ProgressStatus::FIRST_AT_MINUTES / @project.journals.kept.count, created_at: 2.days.ago)
    ProgressStatus.refresh(@project)
    travel_to(1.day.ago) { decide("check_back") }
    assert submit_design(@project).persisted?
    ProgressStatus.refresh(@project)
    assert_equal "check_back", @project.reload.progress_status.due_reason

    decide("check_back", todos: [ "Fix the README" ])
    refute @project.reload.progress_status.due?
    assert_empty ProgressXpHold.where(project: @project), "a second check back in a row holds nothing once it's submitted"
  end

  test "a submitted project under the threshold doesn't come up" do
    submit_design(@project)
    log(FIRST - 1)
    assert_nil @project.reload.progress_status
  end

  test "flagged for AI it leaves the queue but stays due" do
    log(FIRST)
    status = @project.reload.progress_status
    status.update!(flagged_at: Time.current, flag_reason: "Pangram 90%")
    assert_empty ProgressStatus.queued
    assert_equal [ status ], ProgressStatus.flagged.to_a
    assert status.due?
  end

  test "approving needs the must-have checks; check back needs feedback; not on your own team" do
    log(FIRST)
    status = @project.reload.progress_status
    review = ProgressReview.decide(status, reviewer: @reviewer, verdict: "approved", checks: { "hours" => true })
    assert review.errors[:checks].any?
    review = ProgressReview.decide(status, reviewer: @reviewer, verdict: "check_back", checks: {}, todos: [ "x" ])
    assert review.errors[:feedback].any?
    review = ProgressReview.decide(status, reviewer: @project.user, verdict: "check_back", feedback: "Hi", todos: [ "x" ])
    refute review.persisted?
    review = ProgressReview.decide(status, reviewer: @reviewer, verdict: "dismissed")
    refute review.persisted?, "dismiss is only for a check back"
    assert status.reload.due?
    review = ProgressReview.decide(status, reviewer: @reviewer, verdict: "approved", checks: ProgressReview::REQUIRED_CHECKS.index_with { true })
    assert review.persisted?, "the other checks are only noted"
  end

  test "a banned owner's project leaves the queue and comes back when the ban is lifted" do
    log(FIRST)
    assert @project.reload.progress_status.due?
    perform_enqueued_jobs(only: ProgressRefreshJob) { @project.user.update!(is_banned: true) }
    refute @project.reload.progress_status.due?
    perform_enqueued_jobs(only: ProgressRefreshJob) { @project.user.update!(is_banned: false) }
    assert @project.reload.progress_status.due?
  end

  test "the backfill queues projects already over the threshold, waiting from when each crossed it" do
    @project.journals.kept.update_all(duration_minutes: nil, discarded_at: Time.current)
    crossed = 5.days.ago
    @project.journals.create!(user: @project.user, body: "x" * 2_000, duration_minutes: ProgressStatus::FIRST_AT_MINUTES - 60, created_at: 6.days.ago, source: "transfer")
    @project.journals.create!(user: @project.user, body: "x" * 2_000, duration_minutes: 90, created_at: crossed, source: "transfer")
    @project.journals.create!(user: @project.user, body: "x" * 2_000, duration_minutes: 60, created_at: 1.day.ago, source: "transfer")
    @project.journals.kept.update_all(source: "web")
    ProgressStatus.where(project: @project).delete_all
    Rails.application.load_tasks unless Rake::Task.task_defined?("progress_reviews:backfill")
    assert_output(/waiting for journal review/) { Rake::Task["progress_reviews:backfill"].execute }
    status = @project.reload.progress_status
    assert_equal "first", status.due_reason
    assert_in_delta crossed, status.due_since, 1.second
  end

  test "transferred hours don't count: a transferred project is tracked from the transfer on" do
    log(FIRST - 1)
    transfer = @project.journals.create!(user: @project.user, body: "x" * 2_000, duration_minutes: 50 * 60, created_at: 1.day.ago, source: "transfer")
    status = ProgressStatus.refresh(@project)
    refute status.due?, "50 transferred hours don't bring it up"
    assert_equal (FIRST - 1) * 60, status.logged_minutes
    transfer.discard
    add(1)
    assert_equal "first", @project.reload.progress_status.due_reason
  end
end
